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
        pname = "python-app";
        version = "0.1.0";
        src = ./.;
        package = pkgs.python3Packages.buildPythonPackage {
          inherit pname version src;
        };
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = pname;
          tag = version;
          contents = [ package ];
          entrypoint = [
            "${package}/bin/${pname}"
          ];
          config = {
            Env = [ ];
            ExposedPorts = { };
            WorkingDir = "/";
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil
            nixfmt-rfc-style
            python311
            ruff
            basedpyright
            nodePackages.prettier
          ];
        };
        packages.default = package;
        packages.dockerImage = dockerImage;
      }
    );
}
