{
  description = "Experimental, not really community-maintained dinit service modules for finix";

  outputs =
    { ... }:
    {
      nixosModules = builtins.mapAttrs (dir: _: ./modules/${dir}) (builtins.readDir ./modules);
    };
}
