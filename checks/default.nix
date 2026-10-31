{
  pkgs,
  system,
  self,
  nixpkgs,
}: let
  inherit (pkgs) lib;
  harborLib = self.lib;

  render = let
    dxvk = harborLib.mkDxvkConf pkgs {
      "d3d9.maxFrameLatency" = 1;
      "dxvk.tearFree" = true;
    };
    basalt = harborLib.mkVkBasaltConf pkgs {
      effects = "cas";
      casSharpness = 0.35;
    };
  in
    pkgs.runCommand "harbor-game-render" {} ''
      diff ${dxvk} ${pkgs.writeText "dxvk.golden" ''
        d3d9.maxFrameLatency = 1
        dxvk.tearFree = True
      ''}
      diff ${basalt} ${pkgs.writeText "vkBasalt.golden" ''
        casSharpness = 0.35
        effects = cas
      ''}
      touch $out
    '';

  # Eval only: the toplevel and steam derivations are instantiated, never built.
  mkSystem = amc:
    nixpkgs.lib.nixosSystem {
      modules = [
        self.nixosModules.default
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config.allowUnfree = true;
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          system.stateVersion = "26.05";
          harbor-game = {
            steam = {
              enable = true;
              extraArgs = "-cef-disable-gpu";
              extraEnv.LIBVA_DRIVER_NAME = "dummy";
              amc.package = amc;
            };
            ntsync.enable = true;
          };
        }
      ];
    };
  withAmc = mkSystem pkgs.hello;
  withoutAmc = mkSystem null;
  names = c: map lib.getName c.config.programs.steam.extraPackages;

  moduleEval = assert lib.assertMsg (builtins.elem "hello" (names withAmc) && !builtins.elem "hello" (names withoutAmc)) "amc package missing from steam extraPackages";
  assert lib.assertMsg (withAmc.config.programs.steam.package.drvPath != withoutAmc.config.programs.steam.package.drvPath) "amc wrapper not applied to steam";
  assert lib.assertMsg (builtins.elem "ntsync" withAmc.config.boot.kernelModules) "ntsync module not loaded";
  assert lib.assertMsg withAmc.config.programs.gamemode.enable "gamemode not enabled";
  assert lib.assertMsg (withAmc.config.systemd.user.services."app-steam@autostart".serviceConfig.OOMPolicy == "kill") "steam OOMPolicy drop-in missing";
  # Discard the string context so evaluating the toplevel never builds it.
    pkgs.writeText "harbor-game-module-eval" (builtins.unsafeDiscardStringContext "${withAmc.config.system.build.toplevel.drvPath}\n${withoutAmc.config.system.build.toplevel.drvPath}\n");
in {
  inherit render;
  module-eval = moduleEval;
}
