{% if comments -%}
# List the depenencies for your flake
# to update the dependencies run `nix flake upadate`
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
            nil
            nixfmt-rfc-style
          ];
        };
        {% endif -%}
        {% if dev -%}
        {% if comments -%}
        # The derivation. This is what builds your package
        # Update the information here as you wish
        # See https://nix.dev/manual/nix/2.18/language/derivations.html?highlight=mkDerivation
        {% endif -%}
        package.default = pkgs.stdenv.mkDerivation {
          pname = "myProject";
          version = "0.1.0";
          src = ./.;
          buildInputs = [ ];
          nativeBuildInputs = [ ];
        };
        {% endif -%}
      }
    );
}
