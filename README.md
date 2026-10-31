# harbor-game

Generic NixOS gaming plumbing. Nix only, Linux only.

Per-game runtime (prefixes, launch environment) lives in modde-rs. GPU-profile
quirks live in canix-toolbelt, which feeds `steam.extraArgs` and
`steam.extraEnv`. GameMode tuning stays with the host configuration.

## NixOS module

`nixosModules.default` (alias `nixosModules.harbor-game`).

| Option                          | Type           | Default | Effect                                                                                                                                                                                                  |
| ------------------------------- | -------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `harbor-game.steam.enable`      | bool           | `false` | `programs.steam` with GameMode libraries, `gamemoderun` shim that works inside Steam Linux Runtime, protontricks, `programs.gamemode.enable`, and an `OOMPolicy=kill` drop-in for `app-steam@autostart` |
| `harbor-game.steam.extraArgs`   | str            | `""`    | `steam.override { extraArgs }`                                                                                                                                                                          |
| `harbor-game.steam.extraEnv`    | attrsOf str    | `{}`    | `steam.override { extraEnv }`                                                                                                                                                                           |
| `harbor-game.steam.amc.package` | nullOr package | `null`  | When set, Steam starts through `amc prepare --profile steam` and the `gamemoderun` shim through `amc prepare --profile "${AMC_GAME_PROFILE:-game}"`, so admission precedes GameMode registration        |
| `harbor-game.ntsync.enable`     | bool           | `false` | `boot.kernelModules = ["ntsync"]` (the kernel creates `/dev/ntsync` mode 0666, no udev rule needed)                                                                                                     |

`programs.steam.package` is set with `mkDefault`.

## Packages and lib

- `packages.<linux system>.lutris-game-gamemode`: Lutris `prefix_command` that gives a game EBADF-safe,
  size-rotated stdio logs and execs it under `gamemoderun`.
- `lib.mkDxvkConf pkgs settings` and `lib.mkVkBasaltConf pkgs settings`: write
  `dxvk.conf` / `vkBasalt.conf` from a flat attrset as sorted `key = value`
  lines. Bools render `True`/`False`, floats as short decimals (`0.35`), other
  values via `toString`, strings verbatim. DXVK silently ignores unknown keys, so
  verify keys against the dxvk.conf of the DXVK version in use.

## Per-game decision procedure

| Game API / runner            | Translation layer and where its version comes from | Config channel                        | Post-process                    | HDR                                   |
| ---------------------------- | -------------------------------------------------- | ------------------------------------- | ------------------------------- | ------------------------------------- |
| D3D8/9/10/11 via Wine/Lutris | DXVK; bundled DLL or modde-managed `pkgs.dxvk`     | `DXVK_CONFIG_FILE` (`lib.mkDxvkConf`) | vkBasalt (`lib.mkVkBasaltConf`) | D3D11 only (DXGI); D3D9: none         |
| D3D8–11 via Proton (Steam)   | Proton's DXVK (pick Proton version)                | `DXVK_CONFIG_FILE` in launch env      | vkBasalt                        | D3D11 via Proton Wayland + `DXVK_HDR` |
| D3D12                        | vkd3d-proton                                       | `VKD3D_CONFIG`                        | vkBasalt                        | yes (DXGI)                            |
| Native Vulkan                | n/a                                                | game settings                         | vkBasalt                        | game-dependent                        |
| OpenGL                       | n/a (vkBasalt does not apply)                      | game settings                         | none                            | none                                  |

Tiers:

- Tier 0, host: GameMode plus admission, ntsync, layers, `WINEDEBUG=-all` by default.
- Tier 1, quality: CVars/AA, translation-layer version, CAS.
- Tier 2, pacing: frame cap, maxFrameLatency, tearFree, latencySleep, anisotropy, memory cap.

Measurement rule: capture a MangoHud CSV on a fixed scene for 60 s and compare
avg, 1% low and frametime stddev. Change one knob per run and keep only
measured wins.

## Checks

`checks.<system>.render` compares both renderers to golden text.
`checks.<system>.module-eval` evaluates a NixOS system with every option on
(AMC set to a dummy package) and asserts the AMC, ntsync, GameMode and OOM
wiring; it instantiates but never builds Steam.
