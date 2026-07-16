{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.sysklogd-dinit;
in
{
  options.services.sysklogd-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sysklogd](${pkgs.sysklogd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sysklogd;
      defaultText = lib.literalExpression "pkgs.sysklogd";
      description = ''
        The package to use for `sysklogd`.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Additional `sysklogd` configuration. See {manpage}`syslog.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    dinit.services.syslogd = {
      command = "${cfg.package}/bin/syslogd -F";
      type = "process";
      restart = true;
      smooth-recovery = true;
      boot = true;
    };

    environment.etc."syslog.d/nixos.conf".text = cfg.extraConfig;
    environment.etc."syslog.conf".source =
      lib.mkDefault "${cfg.package}/share/doc/sysklogd/syslog.conf";

    system.activation.scripts.var-log = {
      deps = [ "specialfs" ];
      text = "mkdir -p /var/log";
    };
  };
}
