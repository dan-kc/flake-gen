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
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        
        
                        package.default = pkgs.stdenv.mkDerivation {
                          pname = "myProject";
                          version = "0.1.0";  // Escape inner quotes
                          src = ./.;
                          buildInputs = [ ];
                          nativeBuildInputs = [ ];
                        };
                    
      }
    );
}
