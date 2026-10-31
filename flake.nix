{
  description = "Generic NixOS gaming plumbing: Steam, GameMode, admission, ntsync, DXVK/vkBasalt renderers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
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
      import ./checks {inherit pkgs system self nixpkgs;});

    formatter = forAllSystems ({pkgs, ...}: pkgs.alejandra);
  };
}
