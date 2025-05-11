{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        myGoProject = pkgs.buildGoModule {
          pname = "my-go-project";
          version = "0.1.0";
          src = ./.;
          vendorHash = null;
          proxyVendor = true;
          ldflags = [
            "-s" # Strip symbols
            "-w" # Omit DWARF symbol tables
          ];
        };

      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pkgs.go
            golangci-lint
            goimports
            gopls
          ];
        };
        defaultPackage = myGoProject;
      }
    );
}
