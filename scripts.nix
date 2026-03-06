{ pkgs }:
let
  scripts = rec {
    # Start development environment
    start = pkgs.writeShellScriptBin "start" ''
      set -e
      ROOT="$(git rev-parse --show-toplevel)"

      mkdir -p "$ROOT/logs"
      touch "$ROOT/logs/lspmux.log"

      echo "Checking services..."

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        echo "  ✓ LSP Mux already running"
      else
        echo "  → Starting LSP Mux..."
        # Find an available port
        LSPMUX_PORT=""
        for port in $(seq 49152 49252); do
          if ! ${pkgs.iproute2}/bin/ss -tln | grep -q ":$port "; then
            LSPMUX_PORT=$port
            break
          fi
        done
        if [ -z "$LSPMUX_PORT" ]; then
          echo "  ✗ Error: no available port found in range 49152-49252"
          exit 1
        fi
        echo "$LSPMUX_PORT" > "$ROOT/.lspmux.port"

        LSPMUX_DIR="/tmp/ra-$LSPMUX_PORT"
        CONFIG_DIR="$LSPMUX_DIR/lspmux"
        CONFIG_FILE="$CONFIG_DIR/config.toml"
        mkdir -p "$CONFIG_DIR"
        {
          echo "instance_timeout = false"
          echo "gc_interval = 10"
          echo "listen = [\"127.0.0.1\", $LSPMUX_PORT]"
          echo "connect = [\"127.0.0.1\", $LSPMUX_PORT]"
          echo "log_filters = \"info\""
          echo "pass_environment = []"
        } > "$CONFIG_FILE"
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
      set -e
      ROOT="$(git rev-parse --show-toplevel)"
      echo "Stopping services..."

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        rm -f "$ROOT/.lspmux.pid"
        rm -f "$ROOT/.lspmux.port"
        echo "  ✓ LSP Mux stopped"
      else
        rm -f "$ROOT/.lspmux.pid"
        rm -f "$ROOT/.lspmux.port"
        echo "  ✗ LSP Mux not running"
      fi
      echo "Done."
    '';

    # Show status of all services
    status = pkgs.writeShellScriptBin "status" ''
      set -e
      ROOT="$(git rev-parse --show-toplevel)"
      echo "Service Status:"
      echo ""

      # LSP Mux
      if [ -f "$ROOT/.lspmux.pid" ] && kill -0 $(cat "$ROOT/.lspmux.pid") 2>/dev/null; then
        PORT=$(cat "$ROOT/.lspmux.port" 2>/dev/null || echo "unknown")
        echo "  LSP Mux      ✓ Running    localhost:$PORT"
      else
        echo "  LSP Mux      ✗ Stopped"
      fi
    '';
  };
in
builtins.attrValues scripts
