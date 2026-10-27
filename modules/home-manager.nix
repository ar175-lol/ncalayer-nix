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

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start NCALayer with the graphical session via a systemd user service.";
    };

    installCertificates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the NCA RK root certificates into browser NSS databases.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.activation.ncalayerInstallCertificates = lib.mkIf cfg.installCertificates (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${cfg.package}/bin/ncalayer-install-certs || true
      ''
    );

    systemd.user.services.ncalayer = lib.mkIf cfg.autostart {
      Unit = {
        Description = "NCALayer";
        Wants = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/ncalayer";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };

    # pcscd is a system service, enable it via:
    #   services.pcscd.enable = true;
  };
}
