{
  lib,
  stdenv,
  fetchurl,
  unzip,
  gnugrep,
  coreutils,
  patchelf,
  glibc,
  glib,
  gtk2,
  gtk3,
  libX11,
  libXext,
  libXrender,
  libXtst,
  libXi,
  libXrandr,
  libXcursor,
  libXcomposite,
  libXdamage,
  cairo,
  pango,
  gdk-pixbuf,
  fontconfig,
  freetype,
  dbus,
  zlib,
  alsa-lib,
  libGL,
  libGLU,
  cups,
  pcsclite,
  libappindicator-gtk3,
}: let
  # NCALayer ships a prebuilt JRE 8, which is dynamically linked against a
  # glibc loader that does not exist on NixOS (/lib64/ld-linux-*.so.2).
  # Fix up every JRE executable to use the glibc loader from nixpkgs, then
  # provide the rest of its shared libraries through LD_LIBRARY_PATH.
  loader =
    if stdenv.hostPlatform.isAarch64
    then "${glibc}/lib/ld-linux-aarch64.so.1"
    else "${glibc}/lib/ld-linux-x86-64.so.2";

  libPath = lib.makeLibraryPath [
    glibc.out
    glib.out
    gtk2.out
    gtk3.out
    libappindicator-gtk3.out
    libX11.out
    libXext.out
    libXrender.out
    libXtst.out
    libXi.out
    libXrandr.out
    libXcursor.out
    libXcomposite.out
    libXdamage.out
    cairo.out
    pango.out
    gdk-pixbuf.out
    fontconfig.lib
    freetype.out
    dbus.lib
    zlib
    alsa-lib.out
    libGL.out
    libGLU.out
    cups.lib
    (lib.getLib pcsclite)
  ];
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "ncalayer";
    version = "1.4";

    # Repo files only: the launcher and desktop entry. Everything binary is
    # fetched from the official distribution below.
    src = lib.cleanSourceWith {
      src = ./.;
      filter = path: type: let
        base = baseNameOf path;
      in
        !(
          base
          == ".git"
          || base == "result"
          || (type == "unknown")
        );
    };

    # The official NCALayer 1.4 Linux distribution. It already contains the
    # application jar (embedded in `ncalayer.sh`), the bundled JRE 8, accessory
    # tools and certificates, so nothing binary is versioned in this repo.
    official = fetchurl {
      url = "https://ncl.pki.gov.kz/images/NCALayer/ncalayer.zip";
      sha256 = "31f47c126fe56107d76f11c446110dfa09fc397f032a54ef8ee4d7bcaf6461cb";
    };

    nativeBuildInputs = [patchelf unzip gnugrep coreutils];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/ncalayer $out/bin

      # Unpack the official distribution.
      unzip -q "$official" -d official

      # The application jar is appended to `ncalayer.sh` (a self-extracting
      # installer). Strip the shell prologue up to the zip local header.
      jar_offset=$(${gnugrep}/bin/grep -abo -m1 $'\x50\x4b\x03\x04' official/ncalayer.sh \
        | ${coreutils}/bin/cut -d: -f1)
      ${coreutils}/bin/tail -c +"$((jar_offset + 1))" official/ncalayer.sh \
        > $out/lib/ncalayer/ncalayer.jar

      # Application runtime: the bundled JRE 8 and accessory tools from the
      # official distribution.
      cp -r official/additions/jre8_ncalayer $out/lib/ncalayer/jre8_ncalayer
      chmod -R u+w $out/lib/ncalayer/jre8_ncalayer

      # Point every JRE executable at the nixpkgs dynamic loader.
      for f in "$out"/lib/ncalayer/jre8_ncalayer/bin/*; do
        if [ -f "$f" ] && [ "$(head -c 4 "$f")" = "$(printf '\177ELF')" ]; then
          patchelf --set-interpreter "${loader}" "$f"
        fi
      done

      # Launcher
      substitute "$src/ncalayer.sh" $out/bin/ncalayer \
        --replace '@JRE@' "$out/lib/ncalayer/jre8_ncalayer" \
        --replace '@JAR@' "$out/lib/ncalayer/ncalayer.jar" \
        --replace '@PCSC_LIB@' "${lib.getLib pcsclite}/lib/libpcsclite.so.1" \
        --replace '@LD_LIBRARY_PATH@' "${libPath}"
      chmod +x $out/bin/ncalayer

      # Accessory GUIs (statically linked Go binaries that talk to NCALayer).
      install -Dm755 official/additions/showBundleManager $out/bin/showBundleManager
      install -Dm755 official/additions/showSettings $out/bin/showSettings

      # Root certificates, for manual addition to browser trust stores.
      install -Dm644 official/additions/cert/root_rsa.cer $out/share/ncalayer/certs/root_rsa.cer
      install -Dm644 official/additions/cert/nca_rsa.cer $out/share/ncalayer/certs/nca_rsa.cer

      # Menu entries / icons.
      install -Dm644 official/additions/ncalayer.png $out/share/icons/hicolor/512x512/apps/ncalayer.png
      install -Dm644 "$src"/ncalayer.desktop $out/share/applications/ncalayer.desktop

      runHook postInstall
    '';

    meta = with lib; {
      description = "NCALayer - software for working with Kazakhstan EDS (NCA RK)";
      homepage = "https://pki.gov.kz";
      license = licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux"];
      mainProgram = "ncalayer";
    };
  })
