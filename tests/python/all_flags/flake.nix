# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Optional: Add poetry2nix for better Poetry project support
    # poetry2nix = {
    #   url = "github:nix-community/poetry2nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      # poetry2nix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Optional: Add overlays if needed
          # overlays = [ poetry2nix.overlays.default ];
        };
        pname = "python-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root

        # Define Python dependencies
        # This creates a Python environment with your required packages
        pythonVersion = pkgs.python3; # Default Python version
        pythonEnv = pythonVersion.withPackages (
          ps: with ps; [
            # Add your Python project's dependencies here
            # Web frameworks
            # flask
            # fastapi
            # django

            # Data processing
            # numpy
            # pandas
            # scipy

            # CLI utilities
            # click
            # typer

            # Other common libraries
            # requests
            # pillow
            # pyyaml
          ]
        );
        # Define your Python application package
        # Choose the appropriate build approach based on your project structure:
        # 1. buildPythonPackage: For traditional setuptools-based projects
        # 2. poetry2nix: For Poetry-based projects
        # 3. stdenv.mkDerivation: For simple scripts or non-package Python applications
        # Option 1: Standard Python package with setup.py or pyproject.toml
        package = pkgs.python3Packages.buildPythonPackage {
          inherit pname version src;

          # Specify the format of your Python package
          # format = "setuptools"; # Default, alternatives: "pyproject", "flit", "wheel"

          # Propagated build inputs (runtime dependencies)
          # propagatedBuildInputs = with pkgs.python3Packages; [
          #   flask
          #   requests
          # ];

          # Build inputs (build-time dependencies)
          # buildInputs = with pkgs.python3Packages; [
          #   pytest
          # ];

          # Native build inputs (build tools)
          # nativeBuildInputs = with pkgs; [
          #   python3Packages.pip
          # ];

          # Disable tests if they're causing issues
          # doCheck = false;

          # Environment variables for the build
          # PYTHONPATH = "./";
        };

        # Option 2: For Poetry projects (uncomment if using poetry2nix)
        # package = pkgs.poetry2nix.mkPoetryApplication {
        #   inherit pname version src;
        #
        #   # Specify Python version if needed
        #   python = pythonVersion;
        #
        #   # Overrides for dependencies that need special handling
        #   # overrides = pkgs.poetry2nix.overrides.withDefaults (final: prev: {
        #   #   some-package = prev.some-package.overridePythonAttrs (old: {
        #   #     buildInputs = (old.buildInputs or [ ]) ++ [ final.setuptools ];
        #   #   });
        #   # });
        # };

        # Option 3: For simple Python applications without packaging
        # package = pkgs.stdenv.mkDerivation {
        #   inherit pname version src;
        #
        #   buildInputs = [ pythonEnv ];
        #
        #   installPhase = ''
        #     mkdir -p $out/bin
        #     mkdir -p $out/lib/python
        #
        #     # Copy Python source files
        #     cp -r $src/* $out/lib/python/
        #
        #     # Create wrapper script
        #     cat > $out/bin/${pname} << EOF
        #     #!/bin/sh
        #     exec ${pythonEnv}/bin/python $out/lib/python/main.py "\$@"
        #     EOF
        #
        #     chmod +x $out/bin/${pname}
        #   '';
        # };
        # Define the Docker image for your Python application
        # This creates a container with your Python app and its dependencies
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # This includes your Python environment, application code, and any other files
          contents = [
            package # Include your built Python package
            # Additional runtime dependencies
            # pkgs.bash # For shell scripts
            # pkgs.coreutils # For basic Linux utilities
            # pkgs.curl # For HTTP requests

            # Add project files if not already included in the package
            # src
          ];

          # The entrypoint for your Docker container
          # This depends on how your Python application is structured
          entrypoint = [
            "${package}/bin/${pname}" # If your package installs an executable
          ];

          # Configuration for the container
          config = {
            # Environment variables
            Env = [
              # "PYTHONUNBUFFERED=1" # Ensure Python output is sent directly to the container logs
              # "PYTHON_ENV=production"
            ];

            # Exposed ports - common for web services
            ExposedPorts = {
              # "8000/tcp" = {}; # FastAPI/Uvicorn default
              # "5000/tcp" = {}; # Flask default
              # "8080/tcp" = {}; # General web service
            };

            # Working directory inside the container
            WorkingDir = "/";

            # User to run as (for security, avoid running as root)
            # User = "nobody";
          };
        };
      in
      {
        # Development shell with Python tools
        # This provides a comprehensive environment for Python development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Python and core tools
            pythonVersion
            pythonVersion.pkgs.pip
            pythonVersion.pkgs.setuptools
            pythonVersion.pkgs.wheel

            # Virtual environment tools
            pythonVersion.pkgs.virtualenv
            python-lsp-server # Language server for IDE integration

            # Code quality and formatting tools
            black # Code formatter
            isort # Import formatter
            pylint # Linter
            mypy # Type checker
            pythonVersion.pkgs.pytest # Testing framework

            # Dependency management
            poetry # Dependency management (alternative to pip/requirements.txt)

            # Nix tools
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter

            # Optional tools based on your workflow
            # pre-commit # Pre-commit hooks for git
            # bandit # Security linter
            # flake8 # Style guide enforcement
          ];

          # Shell hook to set up the environment
          # shellHook = ''
          #   # Create a virtual environment if it doesn't exist
          #   if [ ! -d .venv ]; then
          #     echo "Creating virtual environment..."
          #     virtualenv .venv
          #   fi
          #
          #   # Activate the virtual environment
          #   source .venv/bin/activate
          #
          #   # Set environment variables
          #   export PYTHONPATH="$PWD:$PYTHONPATH"
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
