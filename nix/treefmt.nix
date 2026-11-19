{harbor-meta}: _: {
  imports = [
    harbor-meta.treefmtModules.nix
    harbor-meta.treefmtModules.toml
  ];
  projectRootFile = "flake.nix";
  settings.excludes = [
    "templates/**"
    "tests/fixtures/**"
    "checks/fixtures/**"
    ".github/workflows/*.yaml"
  ];
}
