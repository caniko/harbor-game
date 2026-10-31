# Per-game Lutris prefix: EBADF-safe stdio plus a `gamemoderun` invocation
# around the game command. Wire per game entry as prefix_command
# (LUTRIS_GAME_NAME selects the per-game log); the launcher entry keeps its
# own octowow-stdio-redir. Lutris may prepend its own `gamemoderun` outside
# prefix_command, so this can nest a second `gamemoderun` inside Lutris's
# own; the wrapper execs the game command rather than supervising it.
# Must exec, not an operator CLI.
{
  writeShellApplication,
  gamemode,
  coreutils,
}:
writeShellApplication {
  name = "lutris-game-gamemode";
  runtimeInputs = [gamemode coreutils];
  text = ''
    log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/lutris-games"
    game="''${LUTRIS_GAME_NAME:-game}"
    # Log segment only: never let a game name escape into a path.
    clean_game=$(printf '%s' "$game" | tr -c 'A-Za-z0-9._-' '_')
    install -d -m 0700 "$log_dir"
    log="$log_dir/$clean_game-stdio.log"
    touch "$log"
    chmod 0600 "$log"
    if [ "$(stat -c %s "$log" 2>/dev/null || echo 0)" -gt 5242880 ]; then
      mv -f "$log.2" "$log.3" 2>/dev/null || true
      mv -f "$log.1" "$log.2" 2>/dev/null || true
      mv -f "$log" "$log.1" 2>/dev/null || true
      touch "$log"
      chmod 0600 "$log"
    fi
    if [ "$#" = 0 ]; then
      echo "lutris-game-gamemode: no game command" >&2
      exit 2
    fi
    exec gamemoderun "$@" </dev/null >>"$log" 2>&1
  '';
}
