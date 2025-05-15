{% if comments -%}
# List the depenencies for your flake
# to update the dependencies run `nix flake upadate`
{% endif -%}
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      fenix,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        {% if comments -%}
        # This overlay adds nightly-rust-analyzer to nixpkgs
        {% endif -%}
        overlays = [ fenix.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        {% if comments -%}
        # This overlay adds nightly-rust-analyzer to nixpkgs
        {% endif -%}
        {% if package %}
        {% if comments -%}
        # Use the latest rust toolchain to build the project
        {% endif -%}
        toolchain = fenix.packages.${system}.minimal.toolchain;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        pname = "package_name";
        package = rustPlatform.buildRustPackage {
          inherit pname;
          version = "0.1.0";
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
        };
        {% endif -%}
      in
      {
        {% if dev -%}
        {% if comments -%}
        # List the depenencies for your devshell
        # To enter the shell run `nix develop`
        # Or install direnv globally, then run `direnv allow` 
        # this will install dev-depenencies whenever you enter this directory
        {% endif -%}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            (fenix.packages.${system}.complete.withComponents [
              "cargo"
              "clippy"
              "rustc"
              "rustfmt"
            ])
            rust-analyzer
            # rust-analyzer-nightly # If you prefer
            nil
            nixfmt-rfc-style
            taplo
          ];
        };
        {% endif -%}
        {% if package %}
        {% if comments -%}
        # The derivation. This is what builds your package
        # Update the information here as you wish
        # See https://nix.dev/manual/nix/2.18/language/derivations.html?highlight=mkDerivation
        {% endif -%}
        package.default = package;
        {% endif -%}
      }
    );
}
