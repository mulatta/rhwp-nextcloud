{
  lib,
  rhwp-cli,
  rhwp-studio,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "rhwp-viewer";
  version = "0.1.0";

  # Nextcloud app id must stay alphanumeric (no dashes), distinct from pname.
  passthru.appId = "rhwpviewer";

  src = ../app;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/rhwpviewer/{js,bin}
    cp -r $src/appinfo $out/rhwpviewer/
    cp -r ${rhwp-studio}/* $out/rhwpviewer/js/
    cp ${lib.getExe rhwp-cli} $out/rhwpviewer/bin/rhwp
    runHook postInstall
  '';

  meta = {
    description = "Nextcloud 33 app: open and edit HWP/HWPX files via rhwp WASM";
    license = lib.licenses.mit;
  };
}
