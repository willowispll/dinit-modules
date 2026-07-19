{ config, pkgs, lib, ... }:
let
  cfg = config.services.seatd-dinit;
in {
  options.services.seatd-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [seatd](${pkgs.seatd.meta.homepage}) as a system service.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "seat";
      description = ''
        Group to own the `seatd` socket.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.optionalAttrs (cfg.group == "seat") {
      seat = { };
    };

    dinit.services.seatd = {
      type = "process";
      command =
        "${pkgs.seatd.bin}/bin/seatd -u root -g ${cfg.group}"
        + lib.optionalString cfg.debug " -l debug";
      waits-for = [ "syslogd" ];
      restart = true;
      smooth-recovery = true;
      boot = true;
    };
  };
}
