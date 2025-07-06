# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      fenix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # This overlay adds the Fenix Rust toolchains to nixpkgs
        overlays = [ fenix.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        # Use the latest stable Rust toolchain for building the package
        # You can change 'minimal' to 'complete' if you need more components
        toolchain = fenix.packages.${system}.minimal.toolchain;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        pname = "package_name";
        version = "0.1.0";
        package = rustPlatform.buildRustPackage {
          inherit pname version;
          src = ./.; # Assumes your Rust project is in the flake's root directory
          cargoLock.lockFile = ./Cargo.lock;

          # Add build inputs specific to your Rust project if needed
          # For example, if you use native libraries
          # buildInputs = with pkgs; [ libpqxx ];

          # Set environment variables during the build if necessary
          # RUST_BACKTRACE = "1";
        };

        # Define the Docker image
        # This creates a layered Docker image based on your built package
        # See https://nix.dev/tutorials/building-and-publishing-docker-images
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # You can add other necessary files here
          contents = [
            package # Include your built Rust binary/package
            # Add any runtime dependencies your binary needs
            # For example: pkgs.glibc pkgs.libpqxx
          ];

          # The entrypoint for your Docker container
          # This specifies what command to run when the container starts
          # Adjust this to match your binary's location within the image
          # By default, packages are installed in /run/current-system/sw/bin
          # or similar paths depending on the package structure.
          # You might need to inspect the `package` derivation to find the exact binary path.
          entrypoint = [ "/run/current-system/sw/bin/${pname}" ];

          # Optional: Set environment variables in the Docker image
          # config.Env = [ "MY_APP_ENV=production" ];

          # Optional: Expose ports
          # config.ExposedPorts = { "8080/tcp" = {}; };

          # Optional: Specify the user to run the entrypoint as
          # config.User = "root"; # or a specific user if created in contents
        };

      in
      {
        # List the dependencies for your devshell
        # To enter the shell run `nix develop`
        # Or install direnv globally, then run `direnv allow`
        # this will install dev-dependencies whenever you enter this directory
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (fenix.packages.${system}.complete.withComponents [
              "cargo"
              "clippy"
              "rustc"
              "rustfmt"
            ])
            rust-analyzer
            # rust-analyzer-nightly # If you prefer a nightly version
            nil # Nix Language Server for Nix files
            nixfmt-rfc-style # Nix code formatter
            taplo # TOML formatter (for Cargo.toml)
            # Add any other development tools here
            # For example: git, editorconfig-checker
          ];

          # Optional: Set environment variables for the dev shell
          # shellHook = ''
          #   export RUST_LOG=debug
          # '';
        };
        # The derivation for your Rust package
        # To build this run `nix build .` or `nix build .#package_name`
        # See https://nix.dev/manual/nix/2.18/language/derivations.html
        packages.default = package;

        # The derivation for your Docker image
        # To build this run `nix build .#dockerImage`
        # The resulting .tar.gz can be loaded into a Docker daemon
        # using `docker load < result`
        packages.dockerImage = dockerImage;
        # An app to build and load the Docker image into your local Docker daemon
        # To run this use `nix run .#docker-build-and-load`
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
