{pkgs ? import <nixpkgs> {}}:
(pkgs.buildFHSEnv {
  name = "ncalayer-fhs";

  targetPkgs = pkgs:
    with pkgs; [
      bash
      unzip
      nssTools
      which
      coreutils
      gnugrep
      gawk

      jdk17

      libX11
      libXext
      libXrender
      libXtst
      libXi
      xmessage
      zenity

      gtk3
      glib
      libappindicator-gtk3
      cairo
      pango
      gdk-pixbuf
      fontconfig
      freetype
      dbus

      # fonts with Cyrillic coverage
      dejavu_fonts
      liberation_ttf
      noto-fonts
    ];

  multiPkgs = pkgs:
    with pkgs; [
      glibc
    ];

  runScript = "bash";

  profile = ''
    export FONTCONFIG_PATH=/etc/fonts
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:${pkgs.dejavu_fonts}/share:${pkgs.noto-fonts}/share"
  '';
}).env
