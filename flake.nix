{
  description = "NCALayer - software for working with Kazakhstan EDS (NCA RK)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    inherit (nixpkgs) lib;
    ncalayerFor = pkgs: pkgs.callPackage ./ncalayer.nix {};

    appShell = pkgs: let
      inherit (pkgs) dejavu_fonts noto-fonts;
    in
      pkgs.buildFHSEnv {
        name = "ncalayer-app";

        targetPkgs = p:
          with p; [
            bash
            unzip
            nssTools
            which
            coreutils
            gnugrep
            gawk
            vim
            xxd
            libnotify
            pcsclite

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
            gsettings-desktop-schemas
            hicolor-icon-theme
            adwaita-icon-theme
            libappindicator-gtk3
            cairo
            pango
            gdk-pixbuf
            fontconfig
            freetype
            dbus

            dejavu_fonts
            liberation_ttf
            noto-fonts
          ];

        multiPkgs = p: [p.glibc];

        runScript = "bash";

        profile = ''
          export FONTCONFIG_PATH=/etc/fonts
          # GSETTINGS_SCHEMAS_PATH is only set by nix-shell hooks, not at
          # FHS-env runtime - point straight at the schemas instead.
          export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS:/run/current-system/sw/share:${dejavu_fonts}/share:${noto-fonts}/share"
        '';
      };

    shell = pkgs:
      pkgs.mkShell {
        packages = with pkgs; [
          nix
          git
          git-lfs

          python3
          unzip
          zip
          file
          binutils
          patchelf
          jq
          ripgrep

          nixfmt-rfc-style
          shellcheck
          shfmt
          alejandra
        ];

        shellHook = ''
          echo "ncalayer shell"
          echo "  nix flake check       - run tests"
          echo "  nix develop .#app     - shell for running the app"
          echo "  nix run .#ncalayer    - run NCALayer"
        '';
      };
  in {
    packages = forAllSystems (system: {
      ncalayer = ncalayerFor nixpkgs.legacyPackages.${system};
      default = ncalayerFor nixpkgs.legacyPackages.${system};
    });

    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = lib.getExe (ncalayerFor nixpkgs.legacyPackages.${system});
      };
    });

    checks = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.callPackage ./checks.nix {ncalayer = ncalayerFor pkgs;};
    });

    devShells = forAllSystems (system: {
      app = appShell nixpkgs.legacyPackages.${system};
      contributors = shell nixpkgs.legacyPackages.${system};
      default = appShell nixpkgs.legacyPackages.${system};
    });

    nixosModules = {
      ncalayer = import ./modules/nixos.nix;
      default = import ./modules/nixos.nix;
    };

    homeModules = {
      ncalayer = import ./modules/home-manager.nix;
      default = import ./modules/home-manager.nix;
    };
  };
}
