# List the dependencies for your flake
# to update the dependencies run `nix flake update`
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Optional: Use a specific OpenTofu version from source
    # opentofu-source = {
    #   url = "github:opentofu/opentofu";
    #   flake = false; # Not a flake, just the source
    # };

    # Optional: Use terragrunt for managing multiple Terraform configurations
    # terragrunt-source = {
    #   url = "github:gruntwork-io/terragrunt";
    #   flake = false;
    # };
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      # Optional: Include inputs if you're using them
      # opentofu-source,
      # terragrunt-source,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # Optional: Add overlays for custom versions of tools
          # overlays = [
          #   # Example overlay for building OpenTofu from source
          #   (final: prev: {
          #     opentofu = prev.buildGoModule {
          #       pname = "opentofu";
          #       version = "1.6.0"; # Specify the version you want
          #       src = opentofu-source;
          #       vendorHash = null; # Set to null for first build to get the correct hash
          #     };
          #   })
          # ];
        };
        # Configuration for Terraform/OpenTofu project
        # Choose between Terraform and OpenTofu
        tfProvider = "opentofu"; # Options: "terraform" or "opentofu"

        # Get the executable based on the provider choice
        tfTool = if tfProvider == "terraform" then pkgs.terraform else pkgs.opentofu;

        # Project metadata
        pname = "terraform-config";
        version = "0.1.0";
        src = ./.; # Assume configuration is in the flake root

        # Choose your cloud provider(s)
        # This affects which CLI tools are included in the dev shell and Docker image
        cloudProviders = [
          # Uncomment the providers you're using
          # "aws"
          # "azure"
          # "google"
          # "digitalocean"
          # "kubernetes"
        ];

        # Get the appropriate cloud CLI tools based on selected providers
        cloudCLIs =
          with pkgs;
          (if builtins.elem "aws" cloudProviders then [ awscli2 ] else [ ])
          ++ (if builtins.elem "azure" cloudProviders then [ azure-cli ] else [ ])
          ++ (if builtins.elem "google" cloudProviders then [ google-cloud-sdk ] else [ ])
          ++ (if builtins.elem "digitalocean" cloudProviders then [ doctl ] else [ ])
          ++ (
            if builtins.elem "kubernetes" cloudProviders then
              [
                kubectl
                kubernetes-helm
              ]
            else
              [ ]
          );

        # Define a package that bundles your Terraform/OpenTofu configuration
        # This is useful for packaging your IaC code for deployment
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;

          # No build needed for Terraform configurations - just package the files
          dontBuild = true;

          # Install phase copies the configuration files to the Nix store
          installPhase = ''
            # Create the output directory
            mkdir -p $out

            # Copy configuration files
            cp -r $src/* $out/

            # Create a wrapper script for easy execution
            # This provides a convenient way to run terraform/opentofu commands
            mkdir -p $out/bin
            cat > $out/bin/${pname} << EOF
            #!/bin/sh
            set -e

            # Change to the directory containing the Terraform files
            cd $out

            # Run the terraform/opentofu command
            exec ${tfTool}/bin/${tfProvider} "\$@"
            EOF

            chmod +x $out/bin/${pname}

            # Optionally generate documentation
            # if command -v terraform-docs >/dev/null 2>&1; then
            #   terraform-docs markdown $out > $out/README.md
            # fi
          '';
        };

        # Define a Docker image for running your Terraform/OpenTofu configuration
        # This creates a container with all necessary tools to apply your infrastructure
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "${tfProvider}-runner";
          tag = version;

          # Contents of the image
          # This includes the Terraform/OpenTofu tool, your configuration, and cloud CLIs
          contents = [
            # Include the appropriate Terraform tool
            tfTool

            # Include your packaged configuration
            package

            # Essential tools for a usable container
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jq

            # Include cloud provider CLIs as needed
          ] ++ cloudCLIs;

          # The entrypoint for the Docker container
          # You can choose between an interactive shell or direct execution of a command
          entrypoint = [
            # Option 1: Interactive shell with tools available
            "${pkgs.bashInteractive}/bin/bash"

            # Option 2: Direct execution of terraform/opentofu command
            # "${tfTool}/bin/${tfProvider}" "apply" "-auto-approve"
          ];

          # Container configuration
          config = {
            # Environment variables
            Env = [
              "TF_IN_AUTOMATION=true"
              # "TF_LOG=INFO"
              # "AWS_REGION=us-west-2"
            ];

            # Working directory inside the container
            # This is where your configuration files are located
            WorkingDir = "${package}";

            # Volumes for persisting state and credentials
            # Volumes = {
            #   "/terraform-state" = {};
            #   "/credentials" = {};
            # };
          };
        };
      in
      {
        # Development shell with infrastructure tools
        # This provides a comprehensive environment for infrastructure development
        devShells.default = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              # Core infrastructure tools
              tfTool # The selected Terraform implementation (terraform or opentofu)

              # Terraform/OpenTofu enhancement tools
              terraform-docs # Generate documentation from Terraform modules
              terraform-ls # Language server for IDE integration
              tflint # Linter for Terraform
              infracost # Cost estimates for Terraform

              # Infrastructure validation and testing tools
              tfsec # Security scanner for Terraform
              terrascan # Security and compliance scanner

              # State and configuration management tools
              terrafrom-inventory # Terraform state inspection
              terragrunt # Terraform wrapper for DRY configurations

              # Nix tools
              nil # Nix Language Server
              nixfmt-rfc-style # Nix formatter

              # Version control tools
              # pre-commit # Pre-commit hooks
              # git # Version control
            ]
            ++ cloudCLIs; # Add the selected cloud provider CLIs

          # Shell hook to set up the environment
          # shellHook = ''
          #   # Create aliases for common commands
          #   alias tf='${tfProvider}'
          #   alias tfi='${tfProvider} init'
          #   alias tfp='${tfProvider} plan'
          #   alias tfa='${tfProvider} apply'
          #
          #   # Set environment variables
          #   export TF_CLI_ARGS_plan="--parallelism=30"
          #   export TF_CLI_ARGS_apply="--parallelism=30"
          #
          #   # Check if credentials are available
          #   if [ -f ~/.aws/credentials ]; then
          #     echo "AWS credentials found"
          #   else
          #     echo "WARNING: AWS credentials not found"
          #   fi
          #
          #   echo "${tfProvider} $(${tfTool}/bin/${tfProvider} version | head -n1)"
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
            echo "Docker image '${tfProvider}-runner:${version}' loaded."
          '';
        };
      }
    );
}
