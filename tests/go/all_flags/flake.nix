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
        pname = "my-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root
        # Define your Go application build
        # This uses buildGoModule which is the standard way to build Go applications in Nix
        package = pkgs.buildGoModule {
          inherit pname version src;
          vendorSha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          # Vendoring configuration - uncomment as needed
          # vendorGoMod = true; # Use this if you run 'go mod vendor'
          # proxyVendor = true; # Use if vendoring through a proxy

          # Conditionally set vendor hash based on whether vendoring is used
          # vendorSha256 = if vendorGoMod then null else "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

          # Build flags - useful for setting variables or build tags
          # buildFlags = [ "-tags=netgo,osusergo" "-trimpath" ];

          # Cross-compilation - useful for building for a different OS/architecture
          # GOOS = "linux";
          # GOARCH = "amd64";
          # CGO_ENABLED = "0"; # Set to "0" to build a static binary
          # Optional: Pre-build or post-build steps
          # preBuild = ''
          #   # Commands to run before the build
          # '';

          # postBuild = ''
          #   # Commands to run after the build
          # '';
        };

        # Define the Docker image for your Go application
        # Go applications are often compiled into a single binary which makes them
        # ideal for containerization with minimal dependencies
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # For Go, we typically only need the compiled binary and minimal runtime
          # dependencies, making for very small images
          contents = [
            package # Include your built Go binary
            # Add any runtime dependencies your Go binary needs
            # Most Go binaries are statically linked and don't need much
            # pkgs.ca-certificates # If your app makes HTTPS requests
            # pkgs.tzdata # If your app needs timezone data
          ];

          # The entrypoint for your Docker container
          # This will typically point to your Go binary
          entrypoint = [ "${package}/bin/${pname}" ];

          # Configuration for the container
          # Examples of common settings for Go applications:
          config = {
            # Environment variables
            Env = [
              # "GO_ENV=production"
              # "PORT=8080"
            ];

            # Exposed ports - common for web services
            ExposedPorts = {
              # "8080/tcp" = {};
            };

            # Working directory inside the container
            WorkingDir = "/";

            # User to run as (for security, avoid running as root)
            # User = "nobody";
          };
        };
      in
      {
        # List the dependencies for your devshell
        # Includes Go development tools, language server, and linters
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Go toolchain and standard tools
            go # Go compiler and standard library
            gopls # Go language server for IDE integration
            gotools # Standard Go tools (goimports, etc.)

            # Go development tools
            golangci-lint # Comprehensive Go linter
            delve # Go debugger
            go-outline # Go symbol extraction utility
            gotests # Go test generation
            gomodifytags # Go tool for modifying struct tags
            impl # Go tool for generating interface method stubs

            # Nix development tools
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter

            # Optional tools based on your workflow
            # mockgen # For generating mocks
            # protobuf # For protocol buffers
            # protoc-gen-go # Go protocol buffers compiler
            # goreleaser # For releasing Go projects
          ];

          # Optional shell hook to set up the environment
          # shellHook = ''
          #   export GOPATH="$PWD/.go"
          #   export PATH="$GOPATH/bin:$PATH"
          #   export GO111MODULE=on
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
