{
  config,
  lib,
  pkgs,
  options,
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
    # The NCALayer binary is unfree. Allow just this package without a global
    # `allowUnfree`. Guarded because the nixpkgs module (and therefore
    # `nixpkgs.config`) is absent when home-manager uses `useGlobalPkgs`.
    nixpkgs.config = lib.mkIf (options ? nixpkgs && options.nixpkgs ? config) {
      allowUnfreePackages = ["ncalayer"];
    };

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
        Environment = lib.optionals (!cfg.installCertificates) ["NCALAYER_SKIP_CERT_INSTALL=1"];
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };

    systemd.user.services.ncalayer-install-certs = lib.mkIf cfg.installCertificates {
      Unit = {
        Description = "Install NCALayer root certificates into browser NSS databases";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/ncalayer-install-certs";
      };
    };

    # Firefox-family browsers create their profile (and an empty cert9.db) on
    # first launch, after the activation-time installer above has already run.
    # Poll periodically so new profiles get the NCALayer certificates without
    # the user having to run anything manually.
    systemd.user.timers.ncalayer-install-certs = lib.mkIf cfg.installCertificates {
      Unit = {
        Description = "Periodically install NCALayer certificates into new browser profiles";
      };
      Timer = {
        Unit = "ncalayer-install-certs.service";
        OnStartupSec = "1min";
        OnUnitActiveSec = "5min";
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };

    # pcscd is a system service, enable it via:
    #   services.pcscd.enable = true;
  };
}
