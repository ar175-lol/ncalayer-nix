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

    installCertificates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the NCA RK root certificates into browser NSS databases.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The NCALayer binary is unfree. Allow just this package so the module works
    # without a global `allowUnfree`. Skipped when an external `nixpkgs.pkgs`
    # instance is supplied, since `nixpkgs.config` is ignored in that case.
    nixpkgs.config = lib.mkIf (!options.nixpkgs.pkgs.isDefined) {
      allowUnfreePackages = ["ncalayer"];
    };

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
        Environment = lib.optionals (!cfg.installCertificates) ["NCALAYER_SKIP_CERT_INSTALL=1"];
      };
    };

    systemd.user.services.ncalayer-install-certs = lib.mkIf cfg.installCertificates {
      description = "Install NCALayer root certificates into browser NSS databases";
      wantedBy = ["default.target"];
      before = ["ncalayer.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/ncalayer-install-certs";
      };
    };

    # Firefox-family browsers create their profile (and an empty cert9.db) on
    # first launch, after the login-time oneshot above has already run. Poll
    # periodically so those profiles get the NCALayer certificates without the
    # user having to run anything manually.
    systemd.user.timers.ncalayer-install-certs = lib.mkIf cfg.installCertificates {
      description = "Periodically install NCALayer certificates into new browser profiles";
      wantedBy = ["timers.target"];
      timerConfig = {
        Unit = "ncalayer-install-certs.service";
        OnStartupSec = "1min";
        OnUnitActiveSec = "5min";
      };
    };
  };
}
