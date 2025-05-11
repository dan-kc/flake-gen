# dev-tools

## Summary

`dev-tools` is a Nix flake generator project, conceptually similar to the [Official Nix Templates](https://github.com/NixOS/templates). It is designed to address specific requirements and preferences:

- **Dev Shell Centric:** Language servers and formatters are included directly within the generated development shell. This is particularly useful for users of minimal NixOS environments who prefer not to install language-specific dependencies globally.
- **No GitHub Actions:**
- **Strictly Flake and envrc:** This project focuses _only_ on generating the `flake.nix` and `.envrc` files, avoiding the inclusion of language-specific code within the generated output.

Additionally, `dev-tools` incorporates some personal preferences, such as utilizing the [fenix rust toolchain](https://github.com/nix-community/fenix) instead of `nixpkgs` unstable for Rust projects, and favoring `fenix` for building over `naersk`.
