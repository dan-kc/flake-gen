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
        pname = "package_name";
        version = "0.1.0";
        # Build your Go project
        # Adjust src and other parameters as needed for your project structure
        package = pkgs.buildGoModule {
          inherit pname version system;
          src = ./.;
          # Optional: vendorGoMod = true; if you're vendoring dependencies
          # Optional: proxyVendor = true; if you're using a proxy for modules
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your Go application
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          contents = [
            package # Include your built Go binary
            # Add any runtime dependencies your Go binary needs
            # For example, if your Go app interacts with a database
            # pkgs.glibc # Often needed for static binaries
          ];

          # The entrypoint for your Docker container
          # Adjust this to match your binary's location within the image
          entrypoint = [ "/run/current-system/sw/bin/${pname}" ];

          # Optional Docker image configuration
          # config.Env = [ "MY_APP_ENV=production" ];
          # config.ExposedPorts = { "8080/tcp" = {}; };
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
            go
            gopls
            gotools
            nil
            nixfmt-rfc-style
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
