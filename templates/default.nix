{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      fenix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # pname = "package_name";
        # package = rustPlatform.buildRustPackage {
        #   inherit pname;
        #   version = "0.1.0";
        #   src = ./.;
        #   cargoLock.lockFile = ./Cargo.lock;
        # };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              nil
              nixfmt-rfc-style
            ];
          };
        packages = {
          default = package;
        };
      }
    );
}
