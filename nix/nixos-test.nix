{ self, pkgs }:

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
    machine.succeed(f"test -f {quoted_app_path}/templates/index.php")
    machine.succeed(
        "OC_PASS='CorrectHorseBatteryStaple42!' nextcloud-occ user:resetpassword --password-from-env root"
    )

    machine.succeed(textwrap.dedent(r"""
        python3 - <<'PY'
        import http.cookiejar
        import re
        import urllib.parse
        import urllib.request

        base = "http://localhost"
        cookies = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cookies)
        )

        login_html = opener.open(base + "/login").read().decode("utf-8", "replace")
        match = re.search(r'data-requesttoken="([^"]+)"', login_html)
        assert match, login_html[:1000]
        token = match.group(1)

        data = urllib.parse.urlencode({
            "user": "root",
            "password": "CorrectHorseBatteryStaple42!",
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
        assert "Viewer route is ready" in html, html[:1000]

        response = opener.open(base + "/apps/rhwpviewer/view/123")
        assert response.status == 200, response.status
        html = response.read().decode("utf-8", "replace")
        assert "rhwpviewer-root" in html, html[:1000]
        assert 'data-file-id="123"' in html, html[:1000]
        PY
    """))
  '';
})
