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
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          # Add your Python project's dependencies here
          # For example: flask requests
        ]);
        {% if package %}
        pname = "package_name";
        version = "0.1.0";
        # Build your Python project
        # This assumes a simple Python package structure
        package = pkgs.buildPythonPackage {
          inherit pname version;
          src = ./.;
          # Optional: Adjust buildPhase, installPhase, etc. for your project
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your Python application
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          contents = [
            pythonEnv # Include the Python environment with dependencies
            ./. # Include your project source code
            # Add any other necessary files or configurations
          ];

          # The entrypoint for your Docker container
          # This will depend on how you run your Python application
          # Example: Running a Python script
          # entrypoint = [ "${pythonEnv}/bin/python" "./main.py" ];
          # Example: Running a web server (e.g., Gunicorn)
          # entrypoint = [ "${pythonEnv}/bin/gunicorn" "-w 4" "app:app" ];
        };
        {% endif %}

      in
      {
        {% if dev -%}
        {% if comments -%}
        # List the dependencies for your devshell
        {% endif -%}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            python3 # Python interpreter
            # Add Python development tools here (using withPackages or individually)
            python3Packages.pip # pip package manager (for dev use)
            python3Packages.virtualenv # virtualenv (optional)
            pyright # Python Language Server
            black # Python formatter
            isort # Python import sorter
            mypy # Python type checker
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter
            # Add any other development tools here
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
