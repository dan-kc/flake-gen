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
        pname = "my-generic-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root

        {% if package %}
        {% if comments -%}
        # Define a basic package that just includes your project source
        # This is useful if your "build" is simply copying your files
        {% endif -%}
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;
          {% if comments -%}
          # If you have a simple build step (like copying), define it here
          # buildPhase = ''
          #   echo "No specific build process defined"
          # '';
          {% endif -%}
          installPhase = ''
            mkdir -p $out/
            cp -r $src/* $out/
          '';
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your application
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          {% if comments -%}
          # Contents of the image
          # This includes your 'package' (your project files) and any runtime dependencies
          {% endif -%}
          contents = [
            package
            {% if comments -%}
            # Add any necessary runtime dependencies here
            # For example: pkgs.bash pkgs.coreutils
            {% endif -%}
          ];

          {% if comments -%}
          # The entrypoint for your Docker container
          # This is crucial and needs to be the command that starts your application
          # Example: Running a script copied into the image
          # entrypoint = [ "/run/current-system/sw/${pname}/path/to/your-script.sh" ];
          # Example: Running a pre-compiled binary
          # entrypoint = [ "/run/current-system/sw/${pname}/path/to/your-binary" ];
          # You need to adjust this path based on how your 'package' derivation
          # installs your files and where your executable/script is located.
          {% endif -%}
          entrypoint = [ "/path/to/your/entrypoint" ];
        };
        {% endif %}

      in
      {
        {% if dev -%}
        {% if comments -%}
        # List the dependencies for your devshell
        # Include general development tools here
        {% endif -%}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter
            {% if comments -%}
            # Add general development tools that aren't language-specific
            # For example: git, curl, jq, yq, editorconfig-checker
            {% endif -%}
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
