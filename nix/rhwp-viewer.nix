{
  buildNpmPackage,
  lib,
  rhwp-cli,
  rhwp-studio,
  stdenv,
}:

let
  filesAction = buildNpmPackage {
    pname = "rhwp-viewer-files-action";
    version = "0.1.0";

    src = lib.fileset.toSource {
      root = ../.;
      fileset = lib.fileset.unions [
        ../app/src
        ../package-lock.json
        ../package.json
      ];
    };

    npmDepsHash = "sha256-rF6cxf8hfFwyzMPqzfOAgFQhOobxkwd86YMHi9pVtOg=";
    npmBuildScript = "build:files-action";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp app/js/files-action.js $out/files-action.js
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "rhwp-viewer";
  version = "0.1.0";

  # Nextcloud app id must stay alphanumeric (no dashes), distinct from pname.
  passthru.appId = "rhwpviewer";

  src = ../app;

  dontBuild = true;

  # `services.nextcloud.extraApps` symlinks $out into nix-apps/<appid>, so the
  # Nextcloud-expected layout (appinfo/, js/, bin/, ...) sits directly at $out.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/{js,bin}
    cp -r $src/appinfo $out/
    cp -r $src/lib $out/
    cp -r $src/templates $out/
    cp -r ${rhwp-studio}/* $out/js/
    cp -r $src/js/. $out/js/
    cp ${filesAction}/files-action.js $out/js/files-action.js
    cp ${lib.getExe rhwp-cli} $out/bin/rhwp
    runHook postInstall
  '';

  meta = {
    description = "Nextcloud 33 app: open and edit HWP/HWPX files via rhwp WASM";
    license = lib.licenses.mit;
  };
}
