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
        # Build your TypeScript project (e.g., using npm or yarn)
        # This assumes your build script is in package.json
        package = pkgs.stdenv.mkDerivation {
          inherit pname version;
          src = ./.;

          # Build dependencies (e.g., Node.js, npm/yarn, build tools)
          buildInputs = with pkgs; [
            nodejs
            npm # or yarn
            # Add any build tools specified in your package.json (like esbuild, swc)
          ];

          # The build phase typically runs your build script (e.g., 'npm run build')
          # Adjust this command based on your project's build process
          buildPhase = ''
            npm install --omit=dev # Install production dependencies
            npm run build # Run your build script (adjust if needed)
          '';

          # The install phase copies the build output to the installation directory
          # Adjust this to copy the necessary files for your application
          installPhase = ''
            mkdir -p $out/
            cp -r dist/ $out/ # Assuming your build outputs to a 'dist' directory
            # You might need to copy package.json, node_modules (if not bundled), etc.
          '';
        };
        {% endif -%}

        {% if docker_image %}
        {% if comments -%}
        # Define the Docker image for your TypeScript application
        {% endif -%}
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          contents = [
            package # Include your built project (e.g., the contents of your 'dist' folder)
            pkgs.nodejs # Include Node.js runtime if needed
            # Add any other necessary files or configurations
          ];

          # The entrypoint for your Docker container
          # This will depend on how you run your TypeScript application
          # Example: Running a Node.js script
          # entrypoint = [ "${pkgs.nodejs}/bin/node" "$out/path/to/your/script.js" ];
          # Example: Running a web server
          # entrypoint = [ "${pkgs.nodejs}/bin/node" "$out/path/to/your/server.js" ];
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
            nodejs # Node.js runtime and npm
            typescript # TypeScript compiler (tsc)
            eslint # Linter
            prettier # Formatter
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter
            # Add any other development tools here (yarn, pnpm, specific build tools)
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
