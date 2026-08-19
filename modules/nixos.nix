{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ncalayer;
in {
  options.services.ncalayer = {
    enable = lib.mkEnableOption "NCALayer (Kazakhstan EDS client)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../ncalayer.nix {};
      defaultText = "pkgs.callPackage ../ncalayer.nix { }";
      description = "NCALayer package to use.";
    };

    enablePcsc = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the pcscd daemon for smartcard readers.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start NCALayer with the graphical session via a systemd user service.";
    };

    enableFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install fonts with Cyrillic coverage for the Java GUI.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    services.pcscd.enable = cfg.enablePcsc;

    fonts.packages = lib.mkIf cfg.enableFonts [
      pkgs.dejavu_fonts
      pkgs.liberation_ttf
      pkgs.noto-fonts
    ];

    systemd.user.services.ncalayer = lib.mkIf cfg.autostart {
      description = "NCALayer";
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/ncalayer";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
