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
        pname = "my-app";
        version = "0.1.0";
        src = ./.;
        package = pkgs.stdenv.mkDerivation {
          inherit pname version src;
          installPhase = ''
            mkdir -p $out/
            cp -r $src/* $out/
          '';
        };
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;
          contents = [
            package
          ];
          entrypoint = [ "/path/to/your/entrypoint" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil
            nixfmt-rfc-style
          ];
        };
        packages.default = package;
        packages.dockerImage = dockerImage;
      }
    );
}
