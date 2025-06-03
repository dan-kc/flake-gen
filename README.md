## Summary

`flake-gen` is a Nix flake generator, conceptually similar to the [Official Nix Templates](https://github.com/NixOS/templates). It is designed to address specific requirements and preferences:

- **Dev Shell Centric:** Language servers and formatters are included directly within the generated development shell. This is particularly useful for users of minimal NixOS environments who prefer not to install language-specific dependencies globally.
- **Strictly essential files only:** This project focuses _only_ on generating the `flake.nix` and `.envrc` and `.gitignore` files, avoiding the inclusion of any code within the generated output.
- **No GitHub Actions**

Additionally, `flake-gen` incorporates some personal preferences. For example the `rust` subcommand uses [fenix](https://github.com/nix-community/fenix) in order to get the latest Rust toolchain instead of `nixpkgs` which is often stale.

I intend to add add support for more languages as and when I need them.

## Currently supported languages

- Agnostic (produces generic language-agnostic files)
- Rust

## Usage

`flake-gen {language} {path}` will generate a flake.nix for the specified language in the specified path. The default flake is pretty bare bones, you can add some option flags to flesh out the template: `flake-gen rust ./test_dir -dpcg`.

### Full list of options:

- `-d` (Adds a devshell to the flake and a `.envrc` file)
- `-p` (Adds a project to the flake. You can build the project with `nix build .`)
- `-c` (Adds helpful comments throughout the flake)
- `-g` (Adds a `.gitignore` file)

## Installation

This project is only available via nix flakes.

### Step 1: Add the input to your flake.nix

```
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-gen.url = "github:dan-kc/flake-gen";
  }
...
```

### Step 2: In your configuration.nix, overlay nixpkgs

```
  nixpkgs.overlays = [
    (final: prev: {
      flake-gen = inputs.flake-gen.packages."${pkgs.system}".default;
    })
  ];
```

### Step 3: In your configuration.nix again, install the package

```
  environment.systemPackages = with pkgs; [
    flake-gen
  ];
```

## Development

### Todo:

- Make the default project name to be the curr dir name.
- Add Rust
- Add Go
- Add Ts
- Make it available for other platforms
