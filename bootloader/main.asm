section .boot
[bits 16]

global start
start:
    mov al, 0x02                ; Set video mode to 80x25 colored text mode
    int 0x10

    mov si, welcome_msg         ; Print welcome message
    call bios_print

    call load_kernel            ; Load kernel into memory
    call prepare_for_32bit      ; Set up the environment for switching to 32 bit
                                ; mode

load_kernel:
    mov si, kernel_loading_msg  ; Print kernel loading message
    call bios_print

    mov bx, kernel_offset       ; Set base register to kernel offset

    call disk_load              ; Load kernel from disk
    ret

prepare_for_32bit:
    mov si, switch_msg
    call bios_print

    ; Due to some short-sighted programmers, the A20 line is disabled by default
    ; on boot. This means that we can't access memory above 1MB. We need to
    ; enable it ourselves.
    mov ax, 0x2401              ; BIOS function to enable A20 line
    int 0x15                    ; enable A20 bit

    cli                         ; Disable interrupts
    lgdt [gdt_descriptor]       ; Load GDT

    ; Enable protected mode by setting 0th bit of cr0 to 1.
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    jmp CODE_SEG:init_32bit     ; Far jump to 32 bit code

bios_print:
    mov ah, 0x0e

.loop
    lodsb
    or al, al
    jz .end
    int 0x10
    jmp .loop

.end:
    mov al, 0xa
    int 0x10
    mov al, 0xd
    int 0x10
    ret

welcome_msg db "Welcome to the bootloader", 0
kernel_loading_msg db "Loading kernel...", 0
switch_msg db "Switching to 32 bit mode...", 0

%include "disk.asm"
%include "gdt.asm"

; MBR magic number
times 510 - ($ - $$) db 0
dw 0xaa55

kernel_offset:
[bits 32]

init_32bit:
    ; Set up segment pointers
    mov ax, DATA_SEG            ; move data segment address to ax
    mov ds, ax                  ; Data segment
    mov ss, ax                  ; Stack segment
    mov es, ax                  ; Extra segment
    mov fs, ax                  ; F segment
    mov gs, ax                  ; G segment

    mov esp, kernel_stack_top   ; Set stack pointer to top of kernel stack

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
    mov edi, 0xb8000            ; Set destination to VGA memory
    mov ah, 0x0f                ; Set attribute to white on black
    jmp .loop

.loop:
    lodsb                       ; Load next byte from string into al
    or al, al                   ; Check if al is 0
    jz .end                     ; If al is 0, end of string reached
    stosw                       ; Store al in VGA memory
    jmp .loop

.end:
    ret

kernel_exec_msg db "Executing kernel...", 0

section .bss
align 4                         ; Align to 4 bytes
kernel_stack_bottom: equ $      ; Set kernel stack bottom to current address
    resb 16384                  ; Reserve 16KB for kernel stack
kernel_stack_top:               ; Set kernel stack top to current address
