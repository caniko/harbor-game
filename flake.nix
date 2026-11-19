{
  description = "Generic NixOS gaming plumbing: Steam, GameMode, admission, ntsync, DXVK/vkBasalt renderers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    harbor-meta = {
      url = "github:caniko/harbor-meta/b494b56e8174557b27956108d3ed7dd0e6425d0b";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = import nixpkgs {inherit system;};
        });
    harbor-meta.treefmtModules = {
      nix = "${inputs.harbor-meta}/nix/treefmt/nix.nix";
      toml = "${inputs.harbor-meta}/nix/treefmt/toml.nix";
    };
    # Standalone, reuse the treefmt-nix pin from the raw harbor-meta source
    # instead of adding its transitive inputs to this flake's graph.
    treefmt-nix =
      inputs.treefmt-nix or (let
        lock = builtins.fromJSON (builtins.readFile "${inputs.harbor-meta}/flake.lock");
        pin = lock.nodes.${lock.nodes.${lock.root}.inputs.treefmt-nix}.locked;
      in {
        lib = import (builtins.fetchTree pin).outPath;
      });
    treefmt =
      forAllSystems ({pkgs, ...}:
        treefmt-nix.lib.evalModule pkgs (import ./nix/treefmt.nix {inherit harbor-meta;}));
  in {
    lib = import ./lib;

    nixosModules = rec {
      harbor-game = import ./nix/module.nix;
      default = harbor-game;
    };

    packages = forAllSystems ({pkgs, ...}: {
      lutris-game-gamemode = pkgs.callPackage ./nix/lutris-game-gamemode.nix {};
    });

    checks = forAllSystems ({
      pkgs,
      system,
      ...
    }:
      import ./checks {inherit pkgs system self nixpkgs;}
      // {
        formatting = treefmt.${system}.config.build.check self;
      });

    formatter = builtins.mapAttrs (_: eval: eval.config.build.wrapper) treefmt;
  };
}
