# Helper scripts for managing lspmux
{ pkgs, env }:
let
  scripts = rec {
    # Start lspmux server
    start = pkgs.writeShellScriptBin "start" ''
      set -e
      ROOT="$(git rev-parse --show-toplevel)"

      mkdir -p "$ROOT/logs"
      touch "$ROOT/logs/lspmux.log"

      echo "Checking services..."

      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        echo "  lspmux already running"
      else
        echo "  Starting lspmux..."
        LSPMUX_DIR="/tmp/ra-${env.LSPMUX_PORT}"
        CONFIG_DIR="$LSPMUX_DIR/lspmux"
        CONFIG_FILE="$CONFIG_DIR/config.toml"
        mkdir -p "$CONFIG_DIR"
        printf '%s\n' '${env.LSPMUX_CONFIG}' > "$CONFIG_FILE"
        XDG_CONFIG_HOME=$LSPMUX_DIR nohup lspmux server &> "$ROOT/logs/lspmux.log" &
        echo $! > "$ROOT/.lspmux.pid"
        disown
        echo "  lspmux started"
      fi

      ${status}/bin/status
      echo ""
      echo "Logs: $ROOT/logs/"
    '';

    # Stop lspmux server
    stop = pkgs.writeShellScriptBin "stop" ''
      set -e
      ROOT="$(git rev-parse --show-toplevel)"
      echo "Stopping services..."

      if [ -f "$ROOT/.lspmux.pid" ] && kill $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        rm -f "$ROOT/.lspmux.pid"
        echo "  lspmux stopped"
      else
        rm -f "$ROOT/.lspmux.pid"
        echo "  lspmux not running"
      fi
      echo "Done."
    '';

    # Show lspmux status
    status = pkgs.writeShellScriptBin "status" ''
      set -e
      ROOT="$(git rev-parse --show-toplevel)"
      echo "Service Status:"
      echo ""

      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        echo "  lspmux: running on localhost:${env.LSPMUX_PORT}"
      else
        echo "  lspmux: stopped"
      fi
    '';
  };
in
builtins.attrValues scripts
