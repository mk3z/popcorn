# Popcorn

This is a small 32-bit kernel written in C and an equally small bootloader written in x86 NASM.

## Running

This will boot the kernel in Qemu.

1. Use Nix.
2. `nix run --impure`

The `--impure` flag is necessary because the flake will use the users nixpkgs channel for the `qemu` package to ensure glibc compatibility.

## Producing a binary

1. Use Nix.
2. `nix build`
