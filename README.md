## Summary

`flake-gen` is a Nix flake generator, conceptually similar to the [Official Nix Templates](https://github.com/NixOS/templates). It is designed to address specific requirements and preferences:

- **Dev Shell Centric:** Language servers and formatters are included directly within the generated development shell. This is particularly useful for users of minimal NixOS environments who prefer not to install language-specific dependencies globally.
- **No GitHub Actions**
- **Strictly Flake and envrc:** This project focuses _only_ on generating the `flake.nix` and `.envrc` files, avoiding the inclusion of language-specific code within the generated output.

Additionally, `flake-gen` incorporates some personal preferences, such as for rust projects using [fenix](https://github.com/nix-community/fenix) for the toolchain instead of `nixpkgs` unstable, and favoring `fenix` for building over `naersk`.

## Usage

`flake-gen --lang {language} {path}` will generate a flake.nix and .envrc for the specified language in the specified path. If you don't specify a `lang` it will output a language agnostic flake.

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


## Supported languages

- rust
- go
- python (working on it)
