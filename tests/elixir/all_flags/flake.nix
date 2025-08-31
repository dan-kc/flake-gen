# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        pname = "elixir-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root

        # Define Elixir/Erlang versions
        erlangVersion = pkgs.erlangR26; # Choose your Erlang version
        elixirVersion = pkgs.elixir_1_16; # Choose your Elixir version

        # Define build options
        # Mix environment
        mixEnv = "prod"; # Options: "dev", "test", "prod"

        # Phoenix-specific options (if using Phoenix)
        isPhoenix = false; # Set to true for Phoenix applications
        # Define your Elixir application package
        # This creates a Nix package from your Elixir project
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;

          # Build dependencies
          buildInputs = [
            erlangVersion
            elixirVersion
            # Add any additional build dependencies
            # pkgs.postgresql # If needed for tests
            # pkgs.nodejs # If using Phoenix with asset compilation
          ];

          # Environment variables for the build
          MIX_ENV = mixEnv;
          MIX_REBAR3 = "${pkgs.rebar3}/bin/rebar3";

          # The build phase fetches dependencies and compiles the application
          buildPhase = ''
            export HOME=$TMPDIR
            mix local.hex --force
            mix local.rebar --force
            mix deps.get --only=${mixEnv}
            mix compile
            ${
              if isPhoenix then
                "
            # For Phoenix applications with assets
            cd assets
            npm install
            npm run deploy
            cd ..
            mix phx.digest
            "
              else
                ""
            }
            mix release
          '';

          # The install phase copies the release to the Nix store
          installPhase = ''
            mkdir -p $out
            cp -r _build/${mixEnv}/rel/${pname}/* $out/

            # Create a wrapper script
            mkdir -p $out/bin
            cat > $out/bin/${pname} << EOF
            #!/bin/sh
            exec $out/bin/${pname} "\$@"
            EOF
            chmod +x $out/bin/${pname}
          '';
        };
        # Define the Docker image for your Elixir application
        # This creates a container optimized for running Elixir/Erlang applications
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # This includes your built Elixir release and minimal runtime dependencies
          contents = [
            package # Include your built Elixir release
            # Essential utilities for a functional container
            pkgs.bash # For shell scripts
            pkgs.coreutils # Basic Linux utilities

            # Include CA certificates if your app makes HTTPS connections
            pkgs.cacert
          ];

          # The entrypoint for your Docker container
          entrypoint = [
            "${package}/bin/${pname}"
            "start"
          ];

          # Configuration for the container
          config = {
            # Environment variables
            Env = [
              "LANG=C.UTF-8"
              "RELEASE_DISTRIBUTION=name"
              # "PORT=4000" # For Phoenix applications
              # "DATABASE_URL=ecto://user:pass@host/database"
              # "SECRET_KEY_BASE=your_production_key"
            ];

            # Exposed ports - common for web services
            ExposedPorts = {
              # "4000/tcp" = {}; # Default Phoenix port
              # "8080/tcp" = {}; # Alternative port
            };

            # Working directory inside the container
            WorkingDir = "/";

            # User to run as (for security, avoid running as root)
            # User = "nobody";
          };
        };
      in
      {
        # Development shell with Elixir and Erlang tools
        # This provides a comprehensive environment for Elixir development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Erlang and Elixir
            erlangVersion
            elixirVersion
            rebar3 # Erlang build tool

            # Elixir development tools
            elixir-ls # Language server for IDE integration

            # Build tools
            gnumake

            # Database tools (if needed)
            # postgresql # If your app uses PostgreSQL
            # Node.js (for Phoenix assets)
            # nodejs # Uncomment if using Phoenix with asset compilation
            # nodePackages.npm
            # Nix tools
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter

            # Optional tools based on your workflow
            # inotify-tools # For file system events (used by Phoenix live reload)
            # docker # For container development
            # docker-compose # For multi-container setups
          ];

          # Shell hook to set up the environment
          # shellHook = ''
          #   # Set up local Hex and rebar
          #   mix local.hex --force
          #   mix local.rebar --force
          #
          #   # Set environment variables
          #   export MIX_HOME=$PWD/.nix-mix
          #   export HEX_HOME=$PWD/.nix-hex
          #   export ERL_LIBS=""
          #   export RELEASE_COOKIE=development_cookie
          #
          #   # For Phoenix projects
          #   # export PHX_SERVER=true
          #
          #   echo "Elixir $(elixir -v | grep Elixir | cut -d ' ' -f 2) on Erlang/OTP $(erl -noshell -eval 'io:fwrite(\"~s\", [erlang:system_info(otp_release)])' -s init stop)"
          # '';
        };
        packages.default = package;
        packages.dockerImage = dockerImage;
        apps.docker-build-and-load = flake-utils.lib.mkApp {
          drv = pkgs.writeScript "docker-build-and-load" ''
            #!/bin/sh
            set -euo pipefail
            echo "Building and loading Docker image..."
            nix build .#dockerImage
            docker load < result
            echo "Docker image '${pname}:${version}' loaded."
          '';
        };
      }
    );
}
