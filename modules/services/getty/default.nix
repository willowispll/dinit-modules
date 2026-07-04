{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.getty-dinit;
in
{
  options.services.getty-dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable `getty`.
      '';
    };

    package = lib.mkOption {
      type = with lib.types; nullOr package;
      default = null;
      description = ''
        The package to use for `getty`.
      '';
      example = lib.literalExpression ''
        pkgs.util-linux // {
          mainProgram = "agetty";
        };
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to {option}`services.getty.package`.
      '';
    };

    ttys = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "tty1"
        "tty2"
        "tty3"
        "tty4"
        "tty5"
        "tty6"
      ];
      description = ''
        The list of tty devices on which to start a login prompt.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc.issue = lib.mkDefault {
      text = ''

        [1;32m<<< welcome to finix >>>[0m

      '';
    };

    dinit.services = lib.genAttrs (map (dev: "getty-${dev}") cfg.ttys) (
      name:
      let
        device = lib.removePrefix "getty-" name;
      in
      {
        type = "process";
        command = "${
          lib.getExe (if cfg.package != null then cfg.package else pkgs.util-linux)
        } ${lib.escapeShellArgs cfg.extraArgs} ${device}";
        restart = true;
        depends-on = [ "mdevd-coldplug" ];
      }
    );
  };
}
