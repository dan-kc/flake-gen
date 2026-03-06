# TypeScript development flake with pnpm
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
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              # TypeScript toolchain
              nodejs
              pnpm
              # Language servers
              typescript-language-server
              nodePackages.prettier
              # Nix tools
              nil
              nixfmt-rfc-style
              # Formatters
              taplo
            ];
          };
      }
    );
}
