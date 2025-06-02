{% if comments -%}
# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{% endif -%}
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Optional: If you need a specific OpenTofu version not in nixpkgs
    # opentofu-source = {
    #   url = "github:opentofu/opentofu";
    #   flake = false; # Not a flake, just the source
    # };
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      # Optional: opentofu-source,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Optional: Overlay to get OpenTofu from source if not in nixpkgs
          # overlays = [
          #   (final: prev: {
          #     opentofu = prev.buildGoModule {
          #       pname = "opentofu";
          #       version = "1.6.0"; # Or the version you want
          #       src = opentofu-source;
          #       vendorHash = "sha256-..."; # <<<<< **FIND THIS HASH**
          #     };
          #   })
          # ];
        };
        src = ./.; # Assume OpenTofu configuration is in the flake root

        {% if package %}
        {% if comments -%}
        # Define a package that just includes your OpenTofu configuration files
        # Useful for packaging your configuration for deployment
        {% endif -%}
        package = pkgs.stdenv.mkDerivation {
          pname = "opentofu-config";
          version = "0.1.0"; # Version of your configuration
          src = ./.; # Your configuration files

          installPhase = ''
            mkdir -p $out/
            cp -r $src/* $out/ # Copy your configuration files
            # Be more selective if needed
          '';
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your OpenTofu configuration
        # This typically includes the OpenTofu executable and your config
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "opentofu-runner"; # A name for the runner image
          tag = "latest"; # Or a version for the runner

          # Contents of the image
          contents = [
            pkgs.opentofu # Include the OpenTofu executable
            package # Include your OpenTofu configuration files
            # Add any other necessary tools or configurations
            # pkgs.awscli2 # If interacting with AWS
          ];

          # The entrypoint for the Docker container
          # This defines what to run when the container starts
          # Example: Running a specific OpenTofu command
          # entrypoint = [ "${pkgs.opentofu}/bin/opentofu" "apply" "-auto-approve" ];
          # Example: Providing an interactive shell with opentofu available
          entrypoint = [ "${pkgs.bash}/bin/bash" ]; # Provide a bash shell

          # Optional: Set the working directory in the container
          # where your config files were copied
          config.WorkingDir = "/run/current-system/sw/${package.pname}-${package.version}"; # <<<<< **ADJUST PATH**
        };
        {% endif %}

      in
      {
        {% if dev -%}
        {% if comments -%}
        # List the dependencies for your devshell
        # Include the opentofu executable and any helper tools
        {% endif -%}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            opentofu # The OpenTofu executable
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter
            # Add any other tools for managing infrastructure
            # terraform-docs # For generating documentation
            # tflint # For linting
            # infracost # For cost estimation
            # cloud provider CLIs (awscli2, azure-cli, gcloud)
          ];
        };
        {% endif -%}

        {% if package %}
        packages.default = package; # Package containing your configuration
        {% endif -%}

        {% if docker_image %}
        packages.dockerImage = dockerImage; # Docker image with opentofu and config
        apps.docker-build-and-load = flake-utils.lib.mkApp {
          drv = pkgs.writeScript "docker-build-and-load" ''
            #!/bin/sh
            set -euo pipefail
            echo "Building and loading Docker image..."
            nix build .#dockerImage
            docker load < result
            echo "Docker image 'opentofu-runner:latest' loaded."
          '';
        };
        {% endif %}
      }
    );
}
