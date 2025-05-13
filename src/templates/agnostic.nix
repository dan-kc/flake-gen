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
        {% if dev_shell %}
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nil
            nixfmt-rfc-style
          ];
        };
        {% endif %}
        {% if package %}
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "{{ package_name }}";
          version = "0.1.0";
          src = ./.;
          buildInputs = [];
          nativeBuildInputs = [];
        };
        {% endif %}
      }
    );
}
