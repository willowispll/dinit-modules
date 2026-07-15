{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceOpts =
    { ... }:
    {
      options = {
        type = lib.mkOption {
          type = lib.types.enum [
            "process"
            "bgprocess"
            "scripted"
            "internal"
          ];
          default = "process";
        };

        command = lib.mkOption {
          type = lib.types.str;
        };

        restart = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };

        smoothRecovery = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };

        waitsFor = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Soft dependencies — service waits for these to start.";
        };

        dependsOn = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Hard dependencies — service won't start until these start.";
        };

        path = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Packages whose bin/ directories are prepended to PATH.";
        };

        logType = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum [
            "file"
            "buffer"
            "none"
          ]);
          default = null;
        };

        logFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    };

  renderService =
    service:
    lib.concatStrings (
      [ "type = ${service.type}\n" ]
      ++ [ "command = ${service.command}\n" ]
      ++ lib.optional service.restart "restart = true\n"
      ++ lib.optional service.smoothRecovery "smooth-recovery = true\n"
      ++ map (s: "waits-for = ${s}\n") service.waitsFor
      ++ map (s: "depends-on = ${s}\n") service.dependsOn
      ++ lib.optional (service.path != [ ]) "env = PATH=${lib.makeSearchPath "bin" service.path}\n"
      ++ lib.optional (service.logType != null) "log-type = ${service.logType}\n"
      ++ lib.optional (service.logFile != null) "logfile = ${service.logFile}\n"
    );
in
{
  options.dinit = {
    enable = lib.mkEnableOption "dinit service manager";

    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule serviceOpts);
      default = { };
      description = "Dinit service definitions rendered to /etc/dinit.d/.";
    };

    boot = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Names of services that are hard dependencies of the boot target.
        These are symlinked into boot.d/ — if any fail, boot fails.
        Services that should start after boot should use waitsFor = [ "boot" ]
        instead of being listed here.
      '';
    };
  };

  config = lib.mkIf config.dinit.enable {
    finit.services.dinit = {
      description = "dinit service manager";
      command = "${pkgs.dinit}/bin/dinit -d /etc/dinit.d boot";
      runlevels = "S12345789";
      log = true;
      respawn = true;
    };

    environment = {
      systemPackages = [ pkgs.dinit ];
      etc =
        (lib.mapAttrs' (
          name: service:
          lib.nameValuePair "dinit.d/${name}" {
            text = renderService service;
            mode = "0644";
          }
        ) config.dinit.services)
        // {
          "dinit.d/boot".text = ''
            type = internal
            depends-on.d = boot.d
          '';
          "dinit.d/boot.d/.keep".text = "";
        };
    };

    system.activation.scripts.dinitBootD = {
      deps = [ "etc" ];
      text = lib.concatMapStrings (
        name: "ln -sf ../${name} /etc/dinit.d/boot.d/${name}\n"
      ) config.dinit.boot;
    };
  };
}
