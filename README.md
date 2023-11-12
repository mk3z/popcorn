# Popcorn

This is a small 32-bit kernel written in C and an equally small bootloader written in x86 NASM.

## Producing a binary

### Nix

`nix build`

### Generic Linux

1. `yasm bootloader/main.asm -f elf32 -o boot.o`

NASM should also work.

2. `gcc -m32 kernel/*.c boot.o -o boot.img -nostdlib -fno-pie -ffreestanding -std=c11 -mno-red-zone -fno-exceptions -nostdlib -Wextra -Werror -T linker.ld`


## Running in QEMU

### Nix

`nix run --impure`

The `--impure` flag is necessary because the flake will use the users nixpkgs channel for the `qemu` package to ensure glibc compatibility.

### Generic Linux

First produce the binary and then run this command.

`qemu-system-x86_64 -snapshot -hda boot.img`
