{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dinit.enable = lib.mkEnableOption "dinit service manager";

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
        let
          services = config.dinit.services or { };

          mkLine =
            name: value:
            if builtins.isBool value then
              "${name} = ${if value then "true" else "false"}\n"
            else if builtins.isList value then
              lib.concatMapStrings (v: "${name} = ${toString v}\n") value
            else if builtins.isAttrs value then
              builtins.throw "dinit: cannot coerce set to string for key '${name}' in service definition"
            else
              "${name} = ${toString value}\n";

          mkServiceFile =
            service:
            lib.concatStrings (
              lib.mapAttrsToList (
                key: value:
                if key == "path" then "env = PATH=${lib.makeSearchPath "bin" value}\n" else mkLine key value
              ) service
            );
        in
        (lib.mapAttrs' (
          name: service:
          lib.nameValuePair "dinit.d/${name}" {
            text = mkServiceFile service;
            mode = "0644";
          }
        ) services)
        // {
          "dinit.d/boot".text = ''
            type = internal
            depends-on.d = boot.d
          '';
        };
    };

    system.activation.scripts.dinitBootD =
      let
        services = builtins.attrNames (config.dinit.services or { });
      in
      lib.mkIf (services != [ ]) ''
        mkdir -p /etc/dinit.d/boot.d
        ${lib.concatMapStrings (name: "ln -sf ../${name} /etc/dinit.d/boot.d/${name}\n") services}
      '';
  };
}
