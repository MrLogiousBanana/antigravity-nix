{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, python3
, zlib
, glibc
}:

let
  version = "1.3.2";
  buildId = "5813501495738368";
in
stdenv.mkDerivation {
  pname = "agy";
  inherit version;

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}-${buildId}/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha256-v4UExyCXyX3nfScbFgvbELlWAxz3nPldlsuUjfFhwl8=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    python3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
    glibc
  ];

  sourceRoot = ".";

  postPatch = ''
    # Apply Open Antigravity eligibility bypass
    python3 ${../../patches/patch_eligibility.py} cli antigravity
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    ln -s $out/bin/agy $out/bin/antigravity-cli
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/agy \
      --set-default DBUS_SESSION_BUS_ADDRESS ""
  '';

  meta = with lib; {
    description = "Google Antigravity CLI (patched with Open Antigravity eligibility bypass)";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
