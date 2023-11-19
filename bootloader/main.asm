section .boot
[bits 16]

global start
start:
    ; Some BIOSes start at 0x07c0:0x0000, others at 0x0000:0x7c00. Far jump to
    ; 0x0000:.main to ensure that the bootloader works on all BIOSes.
    jmp 0x0000:.main

.main:
    xor ax, ax                  ; Set ax to 0.

    ; Set segment registers to 0x0000.
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; Set stack to start of bootloader. The stack grows downwards, so the stack
    ; won't overwrite the bootloader.
    mov sp, start

    cld                         ; Clear direction flag.

    ; Set video mode to 80x25 colored text mode
    mov al, 0x02
    int 0x10

    ; Print welcome message
    mov si, welcome_msg
    call bios_print

    ; Print kernel loading message
    mov si, kernel_loading_msg
    call bios_print

    ; Load kernel from disk

    cli                         ; Disable interrupts until kernel is loaded.

    mov ah, 0x02                ; Read mode

    mov bx, kernel_offset       ; Tell int 13h where to load the kernel to.

    mov dh, 3                   ; Set sector count.
    mov al, dh
    push dx                     ; Save dx to stack because it will be used later
                                ; to check if all sectors were read.

    mov cl, 2                   ; Sector number
                                ; Sectors are 512 bytes long and 1-indexed.
                                ; Since the MBR occupies the first sector, the
                                ; kernel is stored in the second sector.

    mov ch, 0x00                ; Cylinder number
    mov dh, 0x00                ; Head number
                                ; These are both 0-indexed.

    int 0x13                    ; Low level disk service interrupt.
    jc disk_error

    pop dx                      ; Restore dx.
    cmp al, dh                  ; Check if all sectors were read.
    jne sector_error

    sti                         ; Enable interrupts again.

    ; Kernel has now been read from disk to address kernel_offset.

    ; Prepare for 32 bit mode.
    jmp prepare_for_32bit

disk_error:
    mov si, disk_error_msg
    call bios_print
    hlt

sector_error:
    mov si, sector_error_msg
    call bios_print
    hlt

prepare_for_32bit:
    mov si, switch_msg
    call bios_print

    ; Due to some short-sighted programmers, the A20 line is disabled by default
    ; on boot. This means that the program can't access memory above 1MB. It
    ; needs to be enabled before switching to protected mode.
    mov ax, 0x2401              ; BIOS function to enable A20 line.
    int 0x15                    ; enable A20 bit.

    cli                         ; Disable interrupts until kernel creates IDT.

    lgdt [gdt_descriptor]       ; Load GDT.

    ; Enable protected mode by setting 0th bit of cr0 to 1.
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    jmp CODE_SEG:init_32bit     ; Far jump to 32 bit code.

; Print string pointed to by si to screen using BIOS interrupts.
bios_print:
    mov ah, 0x0e

.loop
    lodsb                       ; Load next byte from string into al.
    or al, al                   ; Check if al is 0.
    jz .end                     ; If al is 0, end of string reached.
    int 0x10                    ; BIOS interrupt to print character in al.
    jmp .loop

.end:
    ; Print newline and carriage return.
    mov al, 0xa
    int 0x10
    mov al, 0xd
    int 0x10
    ret

welcome_msg db "Welcome to the bootloader", 0
disk_error_msg db "Disk error", 0
sector_error_msg db "Sector error", 0
kernel_loading_msg db "Loading kernel...", 0
switch_msg db "Switching to 32 bit mode...", 0

%include "gdt.asm"

; MBR magic number
times 510 - ($ - $$) db 0
dw 0xaa55

kernel_offset:
[bits 32]

init_32bit:
    ; Set up segment pointers for 32 bit mode
    mov ax, DATA_SEG            ; Move data segment address to ax.
    mov ds, ax                  ; Data segment
    mov ss, ax                  ; Stack segment
    mov es, ax                  ; Extra segment
    mov fs, ax                  ; F segment
    mov gs, ax                  ; G segment

    mov esp, kernel_stack_top   ; Set stack pointer to top of kernel stack.

    mov esi, kernel_exec_msg
    call vga_print

    call execute_kernel

execute_kernel:
    call clear_screen

    [extern main]
    call main

    cli
    hlt

clear_screen:
    mov edi, 0xb8000            ; Set destination to VGA memory.
    mov eax, 0x0f20             ; Set eax to white space character.
    mov ecx, 80 * 25            ; Number of characters to clear.
    rep stosd                   ; Repeat store eax to edi ecx times.
    ret

vga_print:
    mov edi, 0xb8000            ; Set destination to VGA memory.
    mov ah, 0x0f                ; Set attribute to white on black.
    jmp .loop

.loop:
    lodsb                       ; Load next byte from string into al.
    or al, al                   ; Check if al is 0.
    jz .end                     ; If al is 0, end of string reached.
    stosw                       ; Store al in VGA memory.
    jmp .loop

.end:
    ret

kernel_exec_msg db "Executing kernel...", 0

section .bss
align 4                         ; Align to 4 bytes.
kernel_stack_bottom: equ $      ; Set kernel stack bottom to current address.
    resb 16384                  ; Reserve 16KB for kernel stack.
kernel_stack_top:               ; Set kernel stack top to current address.
