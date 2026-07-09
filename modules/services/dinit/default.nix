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
      etc."dinit.d/boot".text = ''
        type = internal
        depends-on.d = boot.d
      '';
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
