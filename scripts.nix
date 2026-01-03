{ pkgs, env }:
let
  scripts = rec {
    # Start development environment
    start = pkgs.writeShellScriptBin "start" ''
      set -e
      ROOT="$PWD"

      mkdir -p "$ROOT/logs"
      touch "$ROOT/logs/lspmux.log"

      echo "Checking services..."

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        echo "  ✓ LSP Mux already running"
      else
        echo "  → Starting LSP Mux..."
        LSPMUX_DIR="/tmp/ra-${env.LSPMUX_PORT}"
        CONFIG_DIR="$LSPMUX_DIR/lspmux"
        CONFIG_FILE="$CONFIG_DIR/config.toml"
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" <<EOF
        ${env.LSPMUX_CONFIG}
      EOF
        XDG_CONFIG_HOME=$LSPMUX_DIR nohup lspmux server &> "$ROOT/logs/lspmux.log" &
        echo $! > "$ROOT/.lspmux.pid"
        disown
        echo "  ✓ LSP Mux started"
      fi

      ${status}/bin/status
      echo ""
      echo "Logs: $ROOT/logs/"
    '';

    # Stop development environment
    stop = pkgs.writeShellScriptBin "stop" ''
      ROOT="$PWD"
      echo "Stopping services..."

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        rm -f "$ROOT/.lspmux.pid"
        echo "  ✓ LSP Mux stopped"
      else
        rm -f "$ROOT/.lspmux.pid"
        echo "  ✗ LSP Mux not running"
      fi
      echo "Done."
    '';

    # Show status of all services
    status = pkgs.writeShellScriptBin "status" ''
      ROOT="$PWD"
      echo "Service Status:"
      echo ""

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        echo "  LSP Mux      ✓ Running    localhost:${env.LSPMUX_PORT}"
      else
        echo "  LSP Mux      ✗ Stopped"
      fi
    '';
  };
in
builtins.attrValues scripts
