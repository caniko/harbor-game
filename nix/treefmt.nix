{harbor-meta}: _: {
  imports = [
    harbor-meta.treefmtModules.nix
    harbor-meta.treefmtModules.toml
    harbor-meta.treefmtModules.markdown
    harbor-meta.treefmtModules.shell
    harbor-meta.treefmtModules.svg
  ];
  projectRootFile = "flake.nix";
  settings.excludes = [
    "templates/**"
    "tests/fixtures/**"
    "checks/fixtures/**"
    ".github/workflows/*.yaml"
  ];
}
