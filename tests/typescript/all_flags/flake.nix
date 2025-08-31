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
        pname = "typescript-app"; # Default package name
        version = "0.1.0"; # Default version
        src = ./.; # Assume project source is in the flake root
        # Define Node.js version and package manager preference
        nodejs = pkgs.nodejs_20; # LTS version
        packageManager = "npm"; # Options: "npm", "yarn", "pnpm"
        # Package manager commands based on selection
        pmCommands = {
          npm = {
            install = "npm install";
            installProd = "npm install --omit=dev";
            build = "npm run build";
            test = "npm test";
            start = "npm start";
          };
          yarn = {
            install = "yarn install";
            installProd = "yarn install --production";
            build = "yarn build";
            test = "yarn test";
            start = "yarn start";
          };
          pnpm = {
            install = "pnpm install";
            installProd = "pnpm install --prod";
            build = "pnpm build";
            test = "pnpm test";
            start = "pnpm start";
          };
        };
        # Get the commands for the selected package manager
        pm = pmCommands.${packageManager};
        # Define your TypeScript application package
        # This creates a Nix package from your TypeScript project
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;

          # Build dependencies (Node.js, package manager, build tools)
          buildInputs = with pkgs; [
            nodejs
            # Select the appropriate package manager
            (
              if packageManager == "npm" then
                nodejs
              else if packageManager == "yarn" then
                yarn
              else if packageManager == "pnpm" then
                nodePackages.pnpm
              else
                nodejs
            )
            # Add any additional build dependencies
            # python3 # Sometimes needed for node-gyp
            # pkg-config # Sometimes needed for native modules
          ];

          # Environment variables for the build
          NODE_ENV = "production";

          # The build phase installs dependencies and runs the build script
          buildPhase = ''
            export HOME=$(mktemp -d)

            # Install dependencies
            ${pm.installProd}

            # Build the project
            ${pm.build}
          '';

          # The install phase copies the build output and necessary files
          # to the Nix store
          installPhase = ''
            # Create the output directory
            mkdir -p $out/bin
            mkdir -p $out/lib/node_modules/${pname}

            # Copy the built files and necessary runtime files
            cp -r dist $out/lib/node_modules/${pname}/
            cp package.json $out/lib/node_modules/${pname}/

            # For applications with an entry point, create a wrapper script
            # This makes your app executable as '${pname}' from the command line
            cat > $out/bin/${pname} << EOF
            #!${pkgs.bash}/bin/bash
            exec ${nodejs}/bin/node $out/lib/node_modules/${pname}/dist/index.js "\$@"
            EOF
            chmod +x $out/bin/${pname}

            # For web applications, copy any static assets
            # mkdir -p $out/share/${pname}
            # cp -r public/* $out/share/${pname}/
          '';
        };
        # Define the Docker image for your TypeScript application
        # This creates a container optimized for running Node.js applications
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;

          # Contents of the image
          # This includes your built application and the Node.js runtime
          contents = [
            nodejs # Include Node.js runtime
            package # Include your built TypeScript project
            # Essential utilities that might be needed at runtime
            pkgs.bash # For shell scripts
            pkgs.coreutils # For basic Linux utilities

            # Optional dependencies based on your app's needs
            # pkgs.curl # For HTTP requests
            # pkgs.ca-certificates # For HTTPS requests
          ];

          # The entrypoint for your Docker container
          entrypoint = [
            "${package}/bin/${pname}" # Use the wrapper script from the package
          ];

          # Configuration for the container
          config = {
            # Environment variables
            Env = [
              "NODE_ENV=production"
              # "PORT=8080"
              # "LOG_LEVEL=info"
            ];

            # Exposed ports - common for web services
            ExposedPorts = {
              # "3000/tcp" = {}; # Default for many Node.js web frameworks
              # "8080/tcp" = {}; # Alternative common port
            };

            # Working directory inside the container
            WorkingDir = "/app";

            # User to run as (for security, avoid running as root)
            # User = "nobody";
          };
        };
      in
      {
        # Development shell with TypeScript and Node.js tools
        # This provides a comprehensive environment for TypeScript development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js and package management
            nodejs
            # Package manager (based on preference)
            (
              if packageManager == "npm" then
                nodejs
              else if packageManager == "yarn" then
                yarn
              else if packageManager == "pnpm" then
                nodePackages.pnpm
              else
                nodejs
            )

            # TypeScript and core development tools
            nodePackages.typescript # TypeScript compiler
            nodePackages.ts-node # TypeScript execution environment

            # Code quality and formatting tools
            nodePackages.eslint # Linter
            nodePackages.prettier # Formatter

            # IDE support
            nodePackages.typescript-language-server # TypeScript Language Server

            # Build tools commonly used with TypeScript
            nodePackages.esbuild # Fast bundler
            # nodePackages.webpack # Traditional bundler
            # nodePackages.rollup # Module bundler
            # nodePackages.vite # Modern dev server and bundler
            # Testing tools
            nodePackages.jest # Testing framework

            # Nix tools
            nil # Nix Language Server
            nixfmt-rfc-style # Nix formatter

            # Optional tools based on your workflow
            # nodePackages.nodemon # Automatic restart during development
            # nodePackages.npm-check-updates # Update dependencies
            # nodePackages.license-checker # Check package licenses
          ];

          # Shell hook to set up the environment
          # shellHook = ''
          #   export PATH="$PWD/node_modules/.bin:$PATH"
          #
          #   # Display project information
          #   echo "Node.js version: $(node --version)"
          #   echo "TypeScript version: $(npx tsc --version)"
          #   echo "Package manager: ${packageManager}"
          #
          #   # Install dependencies if needed
          #   if [ ! -d node_modules ]; then
          #     echo "Installing dependencies..."
          #     ${pm.install}
          #   fi
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
