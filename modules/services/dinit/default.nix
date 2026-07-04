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
      command = "${pkgs.dinit}/bin/dinit -s /etc/dinit.d";
      runlevels = "S12345789";
      log = true;
      respawn = true;
    };

    environment = {
      systemPackages = [ pkgs.dinit ];
      etc."dinit.d/boot".text = ''
        type = internal
      '';
    };
  };
}
