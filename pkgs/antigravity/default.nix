{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, python3
, alsa-lib
, at-spi2-atk
, at-spi2-core
, cairo
, cups
, dbus
, expat
, gdk-pixbuf
, glib
, gtk3
, libdrm
, libGL
, libnotify
, libpulseaudio
, libsecret
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, xorg
, zlib
, glibc
, src ? null
}:

let
  version = "2.16.0";
  defaultSrc = fetchurl {
    url = "https://github.com/MrLogiousBanana/antigravity-nix/releases/download/v${version}/Antigravity.tar.gz";
    hash = "sha256-hRhbPEH7a5CmeiU6HFhwWFydgPVNOr/pms6NaFa8Dmw=";
  };
  effectiveSrc = if src != null then src else defaultSrc;
in
stdenv.mkDerivation {
  pname = "antigravity";
  inherit version;

  src = effectiveSrc;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    python3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    glibc
    zlib
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libXtst
    xorg.libxcb
  ];

  sourceRoot = "Antigravity-x64";

  postPatch = ''
    # Patch embedded language_server with Open Antigravity eligibility bypass
    if [ -f resources/bin/language_server ]; then
      python3 ${../../patches/patch_eligibility.py} manager resources/bin/language_server
    fi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/antigravity $out/bin $out/share/applications $out/share/icons/hicolor/scalable/apps

    # Copy Electron package tree
    cp -r . $out/share/antigravity/

    # Install desktop icons
    install -Dm644 ${../../assets/antigravity.svg} $out/share/icons/hicolor/scalable/apps/antigravity.svg
    install -Dm644 ${../../assets/antigravity-workspace.svg} $out/share/icons/hicolor/scalable/apps/antigravity-workspace.svg

    # Install desktop files
    install -Dm644 ${./antigravity.desktop} $out/share/applications/antigravity.desktop
    install -Dm644 ${./antigravity-personal.desktop} $out/share/applications/antigravity-personal.desktop
    install -Dm644 ${./antigravity-workspace.desktop} $out/share/applications/antigravity-workspace.desktop

    # Install launcher scripts
    substitute ${./launcher.sh} $out/bin/antigravity \
      --replace-fail "@ANTIGRAVITY_EXEC@" "$out/share/antigravity/antigravity"
    chmod +x $out/bin/antigravity

    ln -s $out/bin/antigravity $out/bin/antigravity-personal
    ln -s $out/bin/antigravity $out/bin/antigravity-workspace

    runHook postInstall
  '';

  postFixup = ''
    # Wrap main electron binary with Wayland hints and library paths
    wrapProgram $out/share/antigravity/antigravity \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        libGL
        libpulseaudio
        alsa-lib
        mesa
        systemd
      ]}" \
      --add-flags "--ozone-platform-hint=auto"
  '';

  meta = with lib; {
    description = "Google Antigravity 2.0 Desktop Application (patched with Open Antigravity)";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
