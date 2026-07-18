{ config, pkgs, lib, ... }:
let
  cfg = config.services.iwd-dinit;
  format = pkgs.formats.ini { };
in {
  options.services.iwd-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.iwd;
      defaultText = lib.literalExpression "pkgs.iwd";
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.iwd-dinit.settings = {
      General.EnableNetworkConfiguration = lib.mkDefault true;
      Network.NameResolvingService = lib.mkDefault "none";
    };

    environment.etc."iwd/main.conf".source = format.generate "main.conf" cfg.settings;

    dinit.services.iwd = {
      type = "process";
      command = "${cfg.package}/libexec/iwd";
      waits-for = [ "syslogd" ];
      restart = true;
      smooth-recovery = true;
      log-type = "file";
      logfile = "/var/log/iwd.log";
      boot = true;
    };
  };
}
