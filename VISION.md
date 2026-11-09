# harbor-game vision

harbor-game is generic NixOS gaming plumbing: a Nix-only, Linux-only component
that turns on Steam and GameMode coherently, enables ntsync, renders DXVK and
vkBasalt configuration from Nix attribute sets, and ships a Lutris wrapper that
runs a game under GameMode with safe, size-rotated stdio logs.

## Problem

Steam, GameMode, Proton, Lutris, DXVK, vkd3d-proton, and vkBasalt each have their
own configuration channel and their own idea of where settings belong. Copying
the same launcher snippets and configuration files between hosts produces
inconsistent behaviour, and a wrapper that gets stdio wrong breaks games with
EBADF.

## Principles

- Stay generic and stay in Nix. There is no per-game runtime here; prefixes and
  launch environment belong to modde-rs, GPU-profile quirks belong to
  canix-toolbelt, and GameMode tuning stays with the host configuration.
- One owner per concern. This module composes Steam, GameMode, and ntsync
  instead of duplicating the modules that already own them.
- Do not override host choices: `programs.steam.package` is set with
  `mkDefault`, and Steam arguments and environment are explicit opt-ins.
- Make admission precede GameMode when both are present, so resource admission
  runs before GameMode registration and the shim still works inside the Steam
  Linux Runtime.
- Render configuration deterministically: `mkDxvkConf` and `mkVkBasaltConf`
  sort keys, render booleans as `True`/`False`, keep floats short, and warn that
  keys must be verified against the DXVK version in use because DXVK silently
  ignores unknown keys.
- Keep the standard opt-out for kernel features: ntsync is a single explicit
  option, not a default.

## Scope

`nixosModules.default` (alias `nixosModules.harbor-game`) with the Steam, GameMode
libraries, `gamemoderun` shim, protontricks, and `OOMPolicy=kill` drop-in; the
optional AMC admission integration; ntsync; the `lutris-game-gamemode` package;
the DXVK and vkBasalt renderers; the per-game translation-layer decision table;
and the checks that diff renderer output against golden files and evaluate the
module with and without the AMC package.

## Non-goals

It does not manage game prefixes, per-game launch options, GPU driver
configuration, or host GameMode tuning, and it does not support non-Linux
systems or non-Nix deployment.

## Direction

No roadmap is documented; the repository currently contains the initial
component together with its module, renderers, and decision table.
