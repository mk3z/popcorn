{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        qemupkgs = import <nixpkgs> { };
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with qemupkgs; [ qemu ];
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "bootloader";
          src = ./.;

          nativeBuildInputs = [ pkgs.yasm ];

          # buildPhase = ''
          #   yasm main.asm -f bin -o bootloader.bin
          #   yasm kernel.asm -f elf32 -o kernel_entry.o
          #   gcc -m32 -ffreestanding -fno-pie -mno-red-zone -fno-exceptions -nostdlib -Werror -c kernel.c -o kernel.o
          #   ld -m elf_i386 -o kernel.bin -Ttext 0x1000 kernel_entry.o kernel.o --oformat binary
          #   cat bootloader.bin kernel.bin > boot.img
          # '';

          buildPhase = ''
            yasm bootloader/main.asm -f elf32 -o boot.o
            gcc -m32 kernel/*.c boot.o -o boot.img -nostdlib -fno-pie -ffreestanding -std=c11 -mno-red-zone -fno-exceptions -nostdlib -Wextra -Werror -T linker.ld
          '';

          installPhase = ''
            mkdir -p $out
            cp boot.img $out/
          '';
        };

        apps.default = {
          type = "app";
          program = "${pkgs.writeShellScript "run" "${qemupkgs.qemu}/bin/qemu-system-x86_64 -snapshot -hda ${self.packages.${system}.default}/boot.img"}";
        };
      }
    );
}
