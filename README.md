# dinit-modules

Experimental, not really community-maintained **dinit service modules** for finix.

Inspired by [finix-community/community-modules](https://github.com/finix-community/community-modules).

---


# expectations

modules in this repository:

- may change rapidly
- may have varying quality levels
- may be minimally maintained
- may not follow all `finix` best practices yet
- may become unmaintained over time

this repository prioritizes:

- experimentation
- collaboration
- ecosystem growth
- low contribution friction

# usage (flake-based)

to use this repository, add the following to your flake inputs:

```
{
  inputs = {
    # other inputs...
    dinit-modules.url = "github:willowispll/dinit-modules";
  }
}
```

then, add the following to your outputs:

```
  outputs =
    inputs@{
      self,
      nixpkgs,
      finix,
      dinit-modules, # <- NEW
      ...
    }:
    {
      nixosConfigurations.your-system = finix.lib.finixSystem {
        # ...

        modules = with inputs.community-modules.nixosModules; [
          # dinit-modules
        ];

        # ...
      };
```

