{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.harbor-game;
  amc = cfg.steam.amc.package;
  prepared = amc != null;
  # Steam Linux Runtime (pressure-vessel) overlays its own /usr/lib over the
  # FHS env, so the libgamemode/libgamemodeauto we ship via extraLibraries are
  # invisible inside SLR. /nix/store IS bind-mounted in, so we resolve gamemode
  # via absolute store paths and pin LD_LIBRARY_PATH so the loader selects the
  # matching ELF class for each Steam/Proton process.
  gamemoderun-slr = pkgs.writeShellScriptBin "gamemoderun" ''
    ${
      if prepared
      then ''
        # GameMode registration must happen after admission: preloading the gate
        # itself would freeze the operations it is waiting to drain.
        exec ${lib.getExe amc} prepare --profile "''${AMC_GAME_PROFILE:-game}" \
          --payload-env "LD_LIBRARY_PATH=${lib.makeLibraryPath [pkgs.gamemode.lib pkgs.pkgsi686Linux.gamemode.lib]}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH-}" \
          --payload-env "LD_PRELOAD=libgamemodeauto.so.0''${LD_PRELOAD:+:}''${LD_PRELOAD-}" -- "$@"
      ''
      else ''
        export LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgs.gamemode.lib pkgs.pkgsi686Linux.gamemode.lib]}''${LD_LIBRARY_PATH:+:}''${LD_LIBRARY_PATH-}"
        export LD_PRELOAD="libgamemodeauto.so.0''${LD_PRELOAD:+:}''${LD_PRELOAD-}"
        exec "$@"
      ''
    }
  '';
in {
  options.harbor-game = {
    steam = {
      enable = lib.mkEnableOption "Steam with GameMode and optional admission control";
      extraArgs = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Extra arguments passed to the Steam client (steam.override extraArgs).";
      };
      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Extra environment for the Steam FHS env (steam.override extraEnv).";
      };
      amc.package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "AMC admission-control package. When set, Steam and the gamemoderun shim start through `amc prepare`.";
      };
    };
    ntsync.enable = lib.mkEnableOption "the ntsync kernel module (Wine NT synchronization)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.steam.enable {
      programs.steam = {
        enable = true;
        package = lib.mkDefault ((pkgs.steam.override {
            inherit (cfg.steam) extraArgs extraEnv;
            extraLibraries = pkgs: [pkgs.gamemode.lib pkgs.pkgsi686Linux.gamemode.lib];
          }).overrideAttrs (old:
            lib.optionalAttrs prepared {
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
              postFixup =
                (old.postFixup or "")
                + ''
                  mv "$out/bin/steam" "$out/bin/steam-amc-payload"
                  makeWrapper ${lib.getExe amc} "$out/bin/steam" \
                    --add-flags "prepare --profile steam -- $out/bin/steam-amc-payload"
                '';
            }));
        # gamemoderun-slr must come first so it shadows pkgs.gamemode's
        # gamemoderun on PATH inside the Steam FHS.
        extraPackages = [gamemoderun-slr pkgs.gamemode] ++ lib.optional prepared amc;
        protontricks.enable = true;
      };
      programs.gamemode.enable = true;

      # Steam respawns steamwebhelper children that the kernel OOM-kills, so a
      # memory crunch turns one dead helper into a respawn storm that keeps
      # eating memory. Kill the whole Steam cgroup on the first OOM event;
      # Restart=no (from the generated autostart unit) prevents respawn. The
      # base unit is created at runtime by systemd-xdg-autostart-generator, so
      # it must be overridden as a drop-in.
      systemd.user.services."app-steam@autostart" = {
        overrideStrategy = "asDropin";
        serviceConfig.OOMPolicy = "kill";
      };
    })

    # The kernel creates /dev/ntsync with mode 0666 (drivers/misc/ntsync.c) and
    # systemd ships no rule for it, so no udev rule is needed.
    (lib.mkIf cfg.ntsync.enable {boot.kernelModules = ["ntsync"];})
  ];
}
