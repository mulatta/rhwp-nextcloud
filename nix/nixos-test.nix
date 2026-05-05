{ self, pkgs }:

let
  sampleHwp = ./fixtures/sample.hwp;
  sampleHwpx = ./fixtures/sample.hwpx;
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

    enabled_apps = machine.succeed("nextcloud-occ app:list --enabled")
    assert "- rhwpviewer: 0.1.0" in enabled_apps, enabled_apps
    app_path = machine.succeed("nextcloud-occ app:getpath rhwpviewer").strip()
    quoted_app_path = shlex.quote(app_path)
    machine.succeed(f"test -x {quoted_app_path}/bin/rhwp")
    machine.succeed(f"{quoted_app_path}/bin/rhwp --help >/dev/null")
    machine.succeed(f"test -f {quoted_app_path}/appinfo/routes.php")
    machine.succeed("grep -q 'RHWP Studio' " + quoted_app_path + "/appinfo/info.xml")
    machine.succeed(f"test -f {quoted_app_path}/lib/AppInfo/Application.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Controller/PageController.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Controller/DocumentController.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Listener/LoadFilesActionScript.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/FileResolver.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/ResolvedFile.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/SvgExportResult.php")
    machine.succeed(f"test -f {quoted_app_path}/lib/Service/SvgPage.php")
    machine.succeed(f"test -f {quoted_app_path}/templates/index.php")
    machine.succeed(f"test -f {quoted_app_path}/js/index.html")
    machine.succeed(f"test -f {quoted_app_path}/js/viewer.js")
    machine.succeed(f"test -f {quoted_app_path}/js/files-action.js")
    machine.succeed(
        "OC_PASS='CorrectHorseBatteryStaple42!' nextcloud-occ user:resetpassword --password-from-env root"
    )
    sample_filename = "한글 제목 샘플.hwp"
    sample_hwpx_filename = "한글 제목 샘플.hwpx"
    sample_dirname = "rhwpviewer-sample-dir"
    sample_path = f"/var/lib/nextcloud/data/root/files/{sample_filename}"
    sample_hwpx_path = f"/var/lib/nextcloud/data/root/files/{sample_hwpx_filename}"
    sample_dir_path = f"/var/lib/nextcloud/data/root/files/{sample_dirname}"
    quoted_sample_path = shlex.quote(sample_path)
    quoted_sample_hwpx_path = shlex.quote(sample_hwpx_path)
    quoted_sample_dir_path = shlex.quote(sample_dir_path)
    machine.succeed(textwrap.dedent(f"""
        install -d -o nextcloud -g nextcloud /var/lib/nextcloud/data/root/files
        install -d -o nextcloud -g nextcloud {quoted_sample_dir_path}
        install -o nextcloud -g nextcloud -m 0640 ${sampleHwp} {quoted_sample_path}
        install -o nextcloud -g nextcloud -m 0640 ${sampleHwpx} {quoted_sample_hwpx_path}
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
        sample_hwpx_filename = "한글 제목 샘플.hwpx"
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

        response = opener.open(base + "/apps/files/")
        assert response.status == 200, response.status
        html = response.read().decode("utf-8", "replace")
        assert "files-action.js" in html, html[:1000]
        action_script = re.search(r'src="([^"]*files-action\.js[^"]*)"', html)
        assert action_script, html[:1000]
        action_response = opener.open(base + action_script.group(1))
        action_js = action_response.read().decode("utf-8", "replace")
        assert "Open in RHWP Studio" in action_js, action_js[:1000]
        assert "Edit with RHWP" not in action_js, action_js[:1000]
        assert "/apps/rhwpviewer/edit/" in action_js, action_js[:1000]
        assert "default" in action_js, action_js[:1000]

        def check_editor(filename):
            file_id = get_file_id(filename)
            response = opener.open(base + f"/apps/rhwpviewer/edit/{file_id}")
            assert response.status == 200, response.status
            assert response.geturl().startswith(base + f"/apps/rhwpviewer/studio/{file_id}"), response.geturl()
            decoded_editor_url = urllib.parse.unquote(response.geturl())
            assert f"/apps/rhwpviewer/api/files/{file_id}/content" in decoded_editor_url, decoded_editor_url
            assert "document.hwp" in decoded_editor_url or "document.hwpx" in decoded_editor_url, decoded_editor_url
            assert "한글" not in decoded_editor_url, decoded_editor_url
            studio_html = response.read().decode("utf-8", "replace")

            content_response = opener.open(base + f"/apps/rhwpviewer/api/files/{file_id}/content")
            assert content_response.status == 200, content_response.status
            assert content_response.headers.get_content_type() == "application/octet-stream", content_response.headers
            content = content_response.read(8)
            assert content.startswith(b"\xd0\xcf\x11\xe0") or content.startswith(b"PK"), content

            assert "wasm-unsafe-eval" in response.headers.get("Content-Security-Policy", ""), response.headers
            assert "rhwp-studio" in studio_html, studio_html[:1000]
            script_match = re.search(r'<script\b([^>]+)src="([^"]+)"', studio_html)
            assert script_match, studio_html[:1000]
            assert "nonce=" in script_match.group(1), script_match.group(0)
            script_src = script_match.group(2)
            assert script_src.startswith("/nix-apps/rhwpviewer/js/assets/"), studio_html[:1000]
            assert 'src="/assets/' not in studio_html, studio_html[:1000]
            assert 'href="/assets/' not in studio_html, studio_html[:1000]
            assert "registerSW.js" not in studio_html, studio_html[:1000]

            asset_response = opener.open(base + script_src)
            assert asset_response.status == 200, asset_response.status
            assert asset_response.headers.get_content_type() == "text/javascript", asset_response.headers
            asset_js = asset_response.read().decode("utf-8", "replace")
            assert "new URL(`./rhwp_bg" in asset_js, asset_js[:1000]
            assert "new URL(`/apps/rhwpviewer" not in asset_js, asset_js[:1000]
            assert "file:`/apps/rhwpviewer" not in asset_js, asset_js[:1000]
            return file_id

        def check_svg_export(filename):
            file_id = get_file_id(filename)
            response = opener.open(base + f"/apps/rhwpviewer/view/{file_id}")
            assert response.status == 200, response.status
            html = response.read().decode("utf-8", "replace")
            assert "rhwpviewer-root" in html, html[:1000]
            assert "rhwpviewer-pages" in html, html[:1000]
            assert "viewer.js" in html, html[:1000]
            assert f'data-file-id="{file_id}"' in html, html[:1000]
            assert file_id in html, html[:1000]
            assert filename in html, html[:1000]

            response = opener.open(base + f"/apps/rhwpviewer/api/files/{file_id}/convert")
            assert response.status == 200, response.status
            payload = json.loads(response.read().decode("utf-8", "replace"))
            assert payload["fileId"] == int(file_id), payload
            assert payload["fileName"] == filename, payload
            assert payload["status"] == "ok", payload
            assert payload["kind"] == "svg", payload
            assert isinstance(payload["pages"], list) and len(payload["pages"]) >= 1, payload
            first_page = payload["pages"][0]
            assert first_page["index"] == 0, payload
            assert isinstance(first_page["bytes"], int) and first_page["bytes"] > 0, payload
            assert first_page["url"].startswith(f"/apps/rhwpviewer/api/files/{file_id}/pages/"), payload
            assert first_page["url"].endswith(".svg"), payload
            assert filename not in first_page["url"], payload
            assert "한글" not in first_page["url"], payload

            page_response = opener.open(base + first_page["url"])
            assert page_response.status == 200, page_response.status
            assert page_response.headers.get_content_type() == "image/svg+xml", page_response.headers
            svg = page_response.read().decode("utf-8", "replace")
            assert "<svg" in svg[:1000], svg[:1000]
            return file_id

        file_id = check_svg_export(sample_filename)
        check_svg_export(sample_hwpx_filename)
        check_editor(sample_filename)
        check_editor(sample_hwpx_filename)

        directory_id = get_file_id(sample_dirname)
        try:
            opener.open(base + f"/apps/rhwpviewer/view/{directory_id}")
            raise AssertionError("directory fileId unexpectedly succeeded")
        except urllib.error.HTTPError as error:
            assert error.code == 404, error.code

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
