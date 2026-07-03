let
  serviceModules = builtins.mapAttrs (dir: _: ./services/${dir}) (
    builtins.removeAttrs (builtins.readDir ./services) [
      "README.md"

      # included by default
    ]
  );
in
{
  default = {};
}
// serviceModules

