{ self, pkgs }:

let
  sampleHwp = ./fixtures/sample.hwp;
in
pkgs.testers.runNixOSTest (_: {
  name = "nextcloud-rhwpviewer";

  node.specialArgs = { inherit self; };

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ ./nextcloud-node.nix ];

      environment.systemPackages = with pkgs; [
        curl
        python3
      ];
    };

  testScript = ''
    import json
    import shlex
    import textwrap

    machine.start()
    machine.wait_until_succeeds(
        "systemctl show nextcloud-setup.service -p Result --value | grep -qx success"
    )
    machine.wait_for_unit("phpfpm-nextcloud.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_for_open_port(80)

    status_raw = machine.wait_until_succeeds(
        "curl --fail --silent --show-error http://localhost/status.php"
    )
    status = json.loads(status_raw)
    assert status["installed"] is True, status

    machine.succeed(
        "nextcloud-occ app:list --enabled | grep -E '^[[:space:]]+- rhwpviewer:'"
    )
    app_path = machine.succeed("nextcloud-occ app:getpath rhwpviewer").strip()
    quoted_app_path = shlex.quote(app_path)
    machine.succeed(f"test -x {quoted_app_path}/bin/rhwp")
    machine.succeed(f"{quoted_app_path}/bin/rhwp --help >/dev/null")
    machine.succeed(f"test -f {quoted_app_path}/appinfo/routes.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/AppInfo/Application.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Controller/PageController.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/FileResolver.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/ResolvedFile.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/SvgExportResult.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/SvgPage.php")
    machine.succeed(f"test -f {quoted_app_path}/templates/index.php")
    machine.succeed(f"test -f {quoted_app_path}/js/viewer.js")
    machine.succeed(
        "OC_PASS='CorrectHorseBatteryStaple42!' nextcloud-occ user:resetpassword --password-from-env root"
    )
    sample_filename = "한글 제목 샘플.hwp"
    sample_dirname = "rhwpviewer-sample-dir"
    sample_path = f"/var/lib/nextcloud/data/root/files/{sample_filename}"
    sample_dir_path = f"/var/lib/nextcloud/data/root/files/{sample_dirname}"
    quoted_sample_path = shlex.quote(sample_path)
    quoted_sample_dir_path = shlex.quote(sample_dir_path)
    machine.succeed(textwrap.dedent(f"""
        install -d -o nextcloud -g nextcloud /var/lib/nextcloud/data/root/files
        install -d -o nextcloud -g nextcloud {quoted_sample_dir_path}
        install -o nextcloud -g nextcloud -m 0640 ${sampleHwp} {quoted_sample_path}
        nextcloud-occ files:scan root
    """))

    machine.succeed(textwrap.dedent(r"""
        python3 - <<'PY'
        import base64
        import http.cookiejar
        import json
        import re
        import urllib.error
        import urllib.parse
        import urllib.request
        import xml.etree.ElementTree as ET

        base = "http://localhost"
        password = "CorrectHorseBatteryStaple42!"
        sample_filename = "한글 제목 샘플.hwp"
        sample_dirname = "rhwpviewer-sample-dir"
        cookies = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cookies)
        )

        def get_file_id(filename):
            body = (
                '<?xml version="1.0" encoding="utf-8" ?>\n'
                '<d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">\n'
                '    <d:prop><oc:fileid /></d:prop>\n'
                '</d:propfind>\n'
            ).encode()
            credentials = base64.b64encode(f"root:{password}".encode()).decode()
            request = urllib.request.Request(
                base + "/remote.php/dav/files/root/" + urllib.parse.quote(filename),
                data=body,
                headers={
                    "Authorization": "Basic " + credentials,
                    "Content-Type": "application/xml",
                    "Depth": "0",
                },
                method="PROPFIND",
            )
            response = urllib.request.urlopen(request)
            assert response.status == 207, response.status
            xml = response.read()
            root = ET.fromstring(xml)
            file_id = root.findtext(".//{http://owncloud.org/ns}fileid")
            assert file_id is not None, xml.decode("utf-8", "replace")
            file_id = file_id.strip()
            assert file_id.isdigit(), file_id
            return file_id

        login_html = opener.open(base + "/login").read().decode("utf-8", "replace")
        match = re.search(r'data-requesttoken="([^"]+)"', login_html)
        assert match, login_html[:1000]
        token = match.group(1)

        data = urllib.parse.urlencode({
            "user": "root",
            "password": password,
            "requesttoken": token,
            "timezone": "UTC",
            "timezone_offset": "0",
        }).encode()

        request = urllib.request.Request(
            base + "/login",
            data=data,
            headers={
                "Origin": base,
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        opener.open(request)

        response = opener.open(base + "/apps/rhwpviewer/")
        assert response.status == 200, response.status
        html = response.read().decode("utf-8", "replace")
        assert "rhwpviewer-root" in html, html[:1000]
        assert "viewer.js" in html, html[:1000]
        assert "Viewer route is ready" in html, html[:1000]

        file_id = get_file_id(sample_filename)
        response = opener.open(base + f"/apps/rhwpviewer/view/{file_id}")
        assert response.status == 200, response.status
        html = response.read().decode("utf-8", "replace")
        assert "rhwpviewer-root" in html, html[:1000]
        assert "rhwpviewer-pages" in html, html[:1000]
        assert "viewer.js" in html, html[:1000]
        assert f'data-file-id="{file_id}"' in html, html[:1000]
        assert file_id in html, html[:1000]
        assert sample_filename in html, html[:1000]

        directory_id = get_file_id(sample_dirname)
        try:
            opener.open(base + f"/apps/rhwpviewer/view/{directory_id}")
            raise AssertionError("directory fileId unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 404, error.code

        response = opener.open(base + f"/apps/rhwpviewer/api/files/{file_id}/convert")
        assert response.status == 200, response.status
        payload = json.loads(response.read().decode("utf-8", "replace"))
        assert payload["fileId"] == int(file_id), payload
        assert payload["fileName"] == sample_filename, payload
        assert payload["status"] == "ok", payload
        assert payload["kind"] == "svg", payload
        assert isinstance(payload["pages"], list) and len(payload["pages"]) >= 1, payload
        first_page = payload["pages"][0]
        assert first_page["index"] == 0, payload
        assert isinstance(first_page["bytes"], int) and first_page["bytes"] > 0, payload
        assert first_page["url"].startswith(f"/apps/rhwpviewer/api/files/{file_id}/pages/"), payload
        assert first_page["url"].endswith(".svg"), payload
        assert sample_filename not in first_page["url"], payload
        assert "한글" not in first_page["url"], payload

        page_response = opener.open(base + first_page["url"])
        assert page_response.status == 200, page_response.status
        assert page_response.headers.get_content_type() == "image/svg+xml", page_response.headers
        svg = page_response.read().decode("utf-8", "replace")
        assert "<svg" in svg[:1000], svg[:1000]

        try:
            opener.open(base + "/apps/rhwpviewer/view/999999999")
            raise AssertionError("bogus viewer fileId unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 404, error.code

        try:
            opener.open(base + "/apps/rhwpviewer/api/files/999999999/convert")
            raise AssertionError("bogus conversion fileId unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 404, error.code

        try:
            opener.open(base + f"/apps/rhwpviewer/api/files/{file_id}/pages/999999.svg")
            raise AssertionError("bogus page unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 404, error.code
        PY
    """))
  '';
})
