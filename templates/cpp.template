{% if comments -%}
# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{% endif -%}
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
        {% if package %}
        pname = "cpp-project";
        version = "0.1.0";
        src = ./.;

        # Define the dependencies your C++ project needs to build
        # Example: if you use Boost or Catch2
        buildInputs = with pkgs; [
          # Add build-time dependencies here
          # boost
          # catch2
        ];

        # Define the dependencies your C++ application needs at runtime
        # These will be included in the Docker image
        runtimeDependencies = with pkgs; [
          # Add runtime dependencies here
          # libstdc++ # Often implicitly included, but good to be aware of
          # libpqxx # If connecting to PostgreSQL
        ];

        # Build your C++ project using stdenv.mkDerivation
        # This example uses CMake. Adjust if you use a different build system.
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src buildInputs;

          # Build system specific configuration
          # For CMake:
          nativeBuildInputs = with pkgs; [ cmake ];
          cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

          # For Meson/Ninja:
          # nativeBuildInputs = with pkgs; [ meson ninja ];
          # mesonFlags = [ "--buildtype=release" ];

          # For Autotools:
          # nativeBuildInputs = with pkgs; [ autoconf automake libtool ];
          # configurePhase = '' ./configure --prefix=$out '';
          # buildPhase = '' make '';
          # installPhase = '' make install '';

          # Adjust installPhase to copy built executables and libraries
          installPhase = ''
            runHook preInstall
            # Example for CMake: Copy built executable
            mkdir -p $out/bin
            cp build/your_executable_name $out/bin/
            # Copy any necessary libraries if they are not in runtimeDependencies
            runHook postInstall
          '';
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your C++ application
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          contents = [
            package # Include your built C++ project (executables, libs)
          ] ++ runtimeDependencies; # Add runtime dependencies

          # The entrypoint for your Docker container
          # This needs to be the absolute path to your executable within the image
          # Adjust based on where your installPhase copied the executable
          entrypoint = [ "/run/current-system/sw/bin/your_executable_name" ]; # <<<<< **ADJUST EXECUTABLE NAME**

          # Optional Docker image configuration
          # config.Env = [ "MY_APP_CONFIG=/etc/app/config.conf" ];
          # config.ExposedPorts = { "8080/tcp" = {}; };
        };
        {% endif %}

      in
      {
        {% if dev -%}
        {% if comments -%}
        # List the dependencies for your devshell
        # Include C++ development tools and the chosen build system
        {% endif -%}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # C++ compiler
            gdb # Debugger
            clang-tools_15 # Clang tools (clangd for LSP, clang-format) - Adjust version
            # gnumake # Make utility
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter
            # Include your chosen build system here
            cmake # For CMake projects
            # meson # For Meson projects
            # ninja # For Meson/Ninja projects
            # autoconf automake libtool # For Autotools projects

            # Add development libraries
            # boost # Boost headers/libraries for development
            # Add any testing frameworks if used for development
            # catch2 # Catch2 for running tests
          ];
        };
        {% endif -%}

        {% if package %}
        packages.default = package;
        {% endif -%}

        {% if docker_image %}
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
        {% endif %}
      }
    );
}
