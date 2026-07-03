{
  description = "Experimental, not really community-maintained dinit service modules for finix";

  outputs =
    { ... }:
    {
      nixosModules = import ./modules;
    };
}
