{ config, pkgs, lib, ... }:
let
  cfg = config.services.iwd-dinit;
  format = pkgs.formats.ini { };
in {
  options.services.iwd-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [iwd](${pkgs.iwd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.iwd;
      defaultText = lib.literalExpression "pkgs.iwd";
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.iwd-dinit.settings = {
      General.EnableNetworkConfiguration = lib.mkDefault true;
      Network.NameResolvingService =
        if config.programs.resolvconf.enable then "resolvconf" else "none";
    };

    environment.systemPackages = [ cfg.package ];

    environment.etc."iwd/main.conf".source = format.generate "main.conf" cfg.settings;

    services.dbus.packages = [ cfg.package ];

    system.activation.scripts.iwd-dir = {
      deps = [ "specialfs" ];
      text = "mkdir -p /var/lib/iwd";
    };

    dinit.services.iwd = {
      type = "process";
      command = "${cfg.package}/libexec/iwd" + lib.optionalString cfg.debug " -d";
      waits-for = [ "dbus" "syslogd" ];
      restart = true;
      smooth-recovery = true;
      log-type = "file";
      logfile = "/var/log/iwd.log";
      boot = true;

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };
  };
}
