# RHWP Studio for Nextcloud

Nextcloud 33 app for opening Hangul Word Processor documents (`.hwp` / `.hwpx`) from the Files app with RHWP Studio.

The app packages RHWP Studio and the `rhwp` CLI with Nix, registers a Nextcloud Files action, and exposes authenticated AppFramework endpoints for document loading, SVG preview export, and save-back.

## Status

- Open `.hwp` / `.hwpx` files from Nextcloud Files.
- Register RHWP Studio as the default Files action for supported documents.
- Render SVG previews through the bundled `rhwp export-svg` CLI.
- Load documents into RHWP Studio without exposing original filenames in URLs.
- Save `.hwp` edits back to the current Nextcloud file.
- `.hwpx` save-back is blocked by upstream RHWP Studio UI at the moment. The Nextcloud save endpoint is format-agnostic, but RHWP Studio currently disables HWPX save before it calls the browser save API.

## NixOS usage

Add the package as a Nextcloud extra app:

```nix
{
  services.nextcloud = {
    enable = true;

    extraApps = {
      rhwpviewer = inputs.rhwp-nextcloud.packages.${pkgs.system}.rhwp-viewer;
    };

    extraAppsEnable = true;
  };
}
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

If your configuration does not enable extra apps automatically, enable it with OCC:

```bash
sudo -u nextcloud nextcloud-occ app:enable rhwpviewer
```

The app id is `rhwpviewer`; the user-facing app name is `RHWP Studio`.

## User workflow

1. Open the Nextcloud Files app.
2. Click a readable `.hwp` or `.hwpx` file.
3. Nextcloud opens `/apps/rhwpviewer/edit/{fileId}` and redirects to RHWP Studio.
4. For `.hwp`, use Studio save / `Ctrl+S` to overwrite the same Nextcloud file.

No per-user default-open setting is required. The app registers a default `@nextcloud/files` action when its Files script is loaded. If an older action label appears after upgrading, hard-refresh the browser to clear cached JS.

## Development checks

```bash
nix fmt
nix build .#rhwp-viewer --no-link
nix build .#checks.x86_64-linux.nextcloud --eval-system x86_64-linux -L
```

The VM check boots Nextcloud 33, enables the app, verifies Files action registration, opens HWP/HWPX fixtures, exports SVG pages, loads Studio assets, and exercises the authenticated save endpoint.

## Notes

`rhwp-viewer` is a Nextcloud app payload package, not a runnable command. Use it through `services.nextcloud.extraApps`, not `nix run`.
