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
        pname = "cpp-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root

        # Configuration for C++ project build
        # Choose your preferred C++ compiler toolchain
        stdenv = pkgs.gcc13Stdenv; # Options: gcc13Stdenv, clangStdenv, etc.

        # Choose your build system
        buildSystem = "cmake"; # Options: "cmake", "meson", "make", "autotools"

        # Define the dependencies your C++ project needs to build
        # Add libraries needed at compile time
        buildInputs = with pkgs; [
          # Standard C++ libraries and tools
          # stdenv.cc.cc.lib # Standard C++ library

          # Common development libraries (uncomment as needed)
          # boost # Boost C++ libraries
          # eigen # Linear algebra library
          # fmt # Formatting library
          # nlohmann_json # JSON library
          # spdlog # Logging library
          # openssl # Cryptography
          # zlib # Compression

          # GUI libraries (uncomment as needed)
          # qt6.qtbase # Qt framework
          # SDL2 # Simple DirectMedia Layer
          # sfml # Simple and Fast Multimedia Library

          # Database libraries (uncomment as needed)
          # libpqxx # PostgreSQL C++ client
          # sqlite # SQLite database
          # mariadb-connector-c # MySQL/MariaDB client
        ];

        # Define the dependencies your C++ application needs at runtime
        # These will be included in the Docker image
        runtimeDependencies = with pkgs; [
          # Runtime libraries
          # stdenv.cc.cc.lib # Standard C++ library (often needed at runtime)

          # Common runtime dependencies (uncomment as needed)
          # openssl # For HTTPS and cryptography
          # zlib # For compression
          # curlFull # For HTTP requests

          # Database runtime dependencies
          # sqlite # SQLite runtime
          # postgresql # PostgreSQL client libraries
        ];
        # Build your C++ project using the selected build system
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;

          # Pass the build dependencies
          inherit buildInputs;

          # Native build inputs (build tools and compilers)
          nativeBuildInputs = with pkgs; [
            # Select the appropriate build tools based on the build system
            (
              if buildSystem == "cmake" then
                [ cmake ]
              else if buildSystem == "meson" then
                [
                  meson
                  ninja
                  pkg-config
                ]
              else if buildSystem == "make" then
                [ gnumake ]
              else if buildSystem == "autotools" then
                [
                  autoconf
                  automake
                  libtool
                  pkg-config
                ]
              else
                [ ]
            )

            # Other build tools that might be needed
            # pkg-config # For finding libraries
            # python3 # Sometimes needed for build scripts
            # bison flex # Parser generators
            # git # Sometimes needed for version info
          ];

          # Set compiler flags and options
          # NIX_CFLAGS_COMPILE = "-O3 -march=native";
          # NIX_CXXFLAGS_COMPILE = "-std=c++20 -Wall -Wextra";
          # Set environment variables for the build
          # CMAKE_PREFIX_PATH = "${pkgs.qt6.qtbase}";
          # Configure the build based on the selected build system
          configurePhase =
            # Choose the appropriate configuration command
            if buildSystem == "cmake" then
              ''
                cmake -B build -S . \
                  -DCMAKE_BUILD_TYPE=Release \
                  -DCMAKE_INSTALL_PREFIX=$out
                  # -DBUILD_SHARED_LIBS=ON
                  # -DBUILD_TESTING=OFF
              ''
            else if buildSystem == "meson" then
              ''
                meson setup build \
                  --prefix=$out \
                  --buildtype=release
                  # --default-library=shared
                  # -Dtests=false
              ''
            else if buildSystem == "autotools" then
              ''
                ./configure --prefix=$out
              ''
            else if buildSystem == "make" then
              ''
                # Most Makefiles don't need a configure phase
                # But you might need to create config.h from config.h.in
                # sed -e "s|@VERSION@|${version}|g" config.h.in > config.h
              ''
            else
              ''
                echo "Unknown build system: ${buildSystem}"
                exit 1
              '';

          # Build the project based on the selected build system
          buildPhase =
            if buildSystem == "cmake" then
              ''
                cmake --build build --config Release --parallel $NIX_BUILD_CORES
              ''
            else if buildSystem == "meson" then
              ''
                ninja -C build -j $NIX_BUILD_CORES
              ''
            else if buildSystem == "make" then
              ''
                make -j $NIX_BUILD_CORES
              ''
            else if buildSystem == "autotools" then
              ''
                make -j $NIX_BUILD_CORES
              ''
            else
              ''
                echo "Unknown build system: ${buildSystem}"
                exit 1
              '';

          # Install the project based on the selected build system
          installPhase =
            if buildSystem == "cmake" then
              ''
                cmake --install build
              ''
            else if buildSystem == "meson" then
              ''
                ninja -C build install
              ''
            else if buildSystem == "make" || buildSystem == "autotools" then
              ''
                make install
              ''
            else
              ''
                # Generic install phase as fallback
                mkdir -p $out/bin
                cp -r bin/* $out/bin/ || true

                # Install libraries if present
                mkdir -p $out/lib
                cp -r lib/* $out/lib/ || true

                # Install headers if present
                mkdir -p $out/include
                cp -r include/* $out/include/ || true
              '';

          # Post-install checks and fixes
          # fixupPhase = ''
          #   # Fix rpath issues if needed
          #   patchelf --set-rpath "${pkgs.lib.makeLibraryPath runtimeDependencies}" $out/bin/*
          # '';

          # Enable detailed logging during the build
          # enableParallelBuilding = true;
          # enableParallelChecking = true;
        };
        # Define the Docker image for your C++ application
        # This creates a container with minimal dependencies for running your C++ app
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # This includes your built C++ application and its runtime dependencies
          contents = [
            package # Include your built C++ project (executables, libs)
            # Add essential utilities for a functional container
            pkgs.bashInteractive # For shell access
            pkgs.coreutils # Basic Linux utilities

            # Include CA certificates if your app makes HTTPS connections
            # pkgs.cacert
          ] ++ runtimeDependencies; # Add runtime dependencies

          # The entrypoint for your Docker container
          # This points to your application's executable
          entrypoint = [ "${package}/bin/${pname}" ];

          # Configuration for the container
          config = {
            # Environment variables
            Env = [
              # "CONFIG_FILE=/etc/app/config.json"
              # "LOG_LEVEL=info"
            ];

            # Exposed ports for network services
            ExposedPorts = {
              # "8080/tcp" = {}; # Web service
              # "5432/tcp" = {}; # PostgreSQL
            };

            # Working directory inside the container
            WorkingDir = "/";

            # User to run as (for security, avoid running as root)
            # User = "nobody";
          };
        };
      in
      {
        # Development shell with C++ tools
        # This provides a comprehensive environment for C++ development
        devShells.default = pkgs.mkShell {
          # Pass build inputs from above
          inherit buildInputs;

          # Additional development tools
          nativeBuildInputs = with pkgs; [
            # Compiler and basic tools
            stdenv.cc # C++ compiler (GCC or Clang, based on stdenv)
            gdb # Debugger
            cmake # Build system

            # Choose your build system tools
            (
              if buildSystem == "cmake" then
                [ cmake ]
              else if buildSystem == "meson" then
                [
                  meson
                  ninja
                  pkg-config
                ]
              else if buildSystem == "make" then
                [ gnumake ]
              else if buildSystem == "autotools" then
                [
                  autoconf
                  automake
                  libtool
                  pkg-config
                ]
              else
                [ ]
            )

            # Code analysis and formatting tools
            clang-tools # Collection of tools including clangd (LSP)
            clang-format # Formatter
            cppcheck # Static analyzer

            # Documentation tools
            doxygen # Documentation generator
            graphviz # For generating diagrams

            # Testing tools
            catch2 # Testing framework

            # Debugging tools
            valgrind # Memory debugging

            # Nix tools
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter

            # Optional development tools based on your workflow
            # ccache # Compiler cache
            # heaptrack # Heap memory profiler
            # include-what-you-use # Include analyzer
            # kcachegrind # Profiler GUI
            # perf # Linux profiler
          ];

          # Set compiler flags for development
          # NIX_CFLAGS_COMPILE = "-g -O0 -fsanitize=address,undefined";

          # Shell hook to set up the environment
          # shellHook = ''
          #   export CXX=clang++
          #   export CC=clang
          #
          #   # Create build directory
          #   mkdir -p build
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
