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
      fenix,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ fenix.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        env = rec {
          LSPMUX_PORT = "8600";
          LSPMUX_LOG_FILE = "./logs/lspmux.log";
          LSPMUX_CONFIG = ''
            instance_timeout = false 
            gc_interval = 10
            listen = ["127.0.0.1", ${LSPMUX_PORT}]
            connect = ["127.0.0.1", ${LSPMUX_PORT}]
            log_filters = "info"
            pass_environment = []
          '';
        };
        scripts = import ./scripts.nix {
          inherit pkgs;
          inherit env;
        };

        pname = "flake-gen";
        version = "0.1.0";
        toolchain = fenix.packages.${system}.minimal.toolchain;
        rustPlatform = pkgs.makeRustPlatform {
          cargo = toolchain;
          rustc = toolchain;
        };
        package = rustPlatform.buildRustPackage {
          inherit pname;
          inherit version;
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.nixfmt-rfc-style
          ];
          doCheck = false;
          postInstall = ''
            mkdir -p $out/share/${pname}/templates
            cp -r ./templates/* $out/share/${pname}/templates
          '';
          postFixup = ''
            wrapProgram $out/bin/${pname} \
              --set TEMPLATES_DIR "$out/share/${pname}/templates" \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.nixfmt-rfc-style ]}
          '';
        };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              (fenix.packages.${system}.complete.withComponents [
                "cargo"
                "clippy"
                "rustc"
                "rustfmt"
              ])
              rust-analyzer
              nil
              nixfmt-rfc-style
              nodePackages.prettier
              taplo
              lspmux
            ]
            ++ scripts;
            shellHook = ''
              export LSPMUX_PORT="${env.LSPMUX_PORT}"
                status 
            '';
          };
        packages.default = package;
      }
    );
}
