## Summary

`flake-gen` is a Nix flake generator for quickly bootstrapping development environments.

- **Dev Shell Centric:** Language servers and formatters are included directly within the generated development shell
- **Essential files only:** Generates `flake.nix`, `.envrc`, `.gitignore`, and language-specific helpers (like `scripts.nix` for Rust)
- **LSP Multiplexer support:** The Rust template includes [lspmux](https://github.com/nix-community/lspmux) integration for better IDE performance

## Supported Languages

- `agnostic` - Generic language-agnostic flake
- `rust` - Rust with [fenix](https://github.com/nix-community/fenix) toolchain and lspmux

## Usage

```
flake-gen <language> [path]
```

### Examples

```bash
# Generate rust flake in current directory
flake-gen rust

# Same as above (. means current directory)
flake-gen rust .

# Generate in a new project folder
flake-gen rust my-project

# Include comments in generated files
flake-gen -c rust my-project
```

### Options

- `-c, --comments` - Include helpful comments in generated files

### Generated Files

**Rust:**
- `flake.nix` - Nix flake with fenix toolchain and lspmux
- `scripts.nix` - Helper scripts for managing lspmux (start/stop/status)
- `.envrc` - direnv configuration
- `.gitignore` - Common ignores for Rust/Nix projects

**Agnostic:**
- `flake.nix` - Basic Nix flake with empty devShell
- `.envrc` - direnv configuration
- `.gitignore` - Common ignores for Nix projects

### File Collision Handling

- If `flake.nix` or `scripts.nix` already exists, creates `flake_1.nix`, `flake_2.nix`, etc.
- If `.envrc` or `.gitignore` already exists, appends the new content

## Installation

### Via Nix Flakes

Add to your flake inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-gen.url = "github:dan-kc/flake-gen";
  };
  # ...
}
```

Then either:

**Option A: Add to system packages via overlay**

```nix
nixpkgs.overlays = [
  (final: prev: {
    flake-gen = inputs.flake-gen.packages."${pkgs.system}".default;
  })
];

environment.systemPackages = with pkgs; [
  flake-gen
];
```

**Option B: Run directly**

```bash
nix run github:dan-kc/flake-gen -- rust .
```
