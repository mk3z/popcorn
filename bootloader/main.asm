section .boot
[bits 16]

global start
start:
    jmp 0x0000:.main            ; Some BIOSes start at 0x07c0:0x0000, others at
                                ; 0x0000:0x7c00. Far jump to 0x0000:.main to
                                ; ensure that the bootloader works on all
                                ; BIOSes.

.main:
    xor ax, ax                  ; Clear ax.

    mov ss, ax                  ; Set up segment registers.
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov sp, start               ; Set stack to start of bootloader. The stack
                                ; grows downwards, so the stack won't overwrite
                                ; the bootloader.

    cld                         ; Clear direction flag.

    mov [BOOT_DRIVE], dl        ; Save boot drive number to BOOT_DRIVE.

    mov al, 0x02                ; Set video mode to 80x25 colored text mode
    int 0x10

                                ; Check whether CPU supports CPUID.

    pushfd                      ; Push flags register to stack.
    pop eax                     ; Pop flags register to eax.

    mov ecx, eax                ; Backup flags register to ecx.

    xor eax, 1 << 21            ; Flip bit 21 of flags register.

    push eax                    ; Push new flags register to stack.
    popfd                       ; Store new flags register.

    pushfd                      ; Push flags register to stack.
    pop eax                     ; Pop flags register to eax.

    push ecx                    ; Push old flags register to stack.
    popfd                       ; Store old flags register.

    xor eax, ecx                ; If the flags register was changed, the CPU
                                ; supports CPUID.
    jz cpuid_error

    mov eax, 0x80000000         ; Check whether long mode is available.
    cpuid
    cmp eax, 0x80000001
    jb cpu_error

    mov eax, 0x80000001         ; Check whether long mode is suppprted.
    cpuid
    test edx, 1 << 29
    jz cpu_error

    mov si, kernel_loading_msg  ; Print kernel loading message
    call bios_print

                                ; Load kernel from disk

    cli                         ; Disable interrupts until kernel is loaded.

    mov dl, [BOOT_DRIVE]        ; Set dl to boot drive number.

    mov ah, 0x02                ; Read mode

    mov bx, KERNEL_OFFSET       ; Tell int 13h where to load the kernel to.

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

                                ; Kernel has now been read from disk to address
                                ; KERNEL_OFFSET.

    jmp prepare_long_mode
                                
cpuid_error
    mov si, cpuid_error_msg
    call bios_print
    jmp haltloop

cpu_error
    mov si, cpu_error_msg
    call bios_print
    jmp haltloop

disk_error:
    mov si, disk_error_msg
    call bios_print
    jmp haltloop

sector_error:
    mov si, sector_error_msg
    call bios_print
    jmp haltloop

bios_print:                     ; Print string pointed to by si to screen using
                                ; BIOS interrupts.
    mov ah, 0x0e

    .loop
        lodsb                   ; Load next byte from string into al.
        or al, al               ; Check if al is 0.
        jz .end                 ; If al is 0, end of string reached.
        int 0x10                ; BIOS interrupt to print character in al.
        jmp .loop

    .end:
        mov al, 0xa             ; Print newline and carriage return.
        int 0x10
        mov al, 0xd
        int 0x10
        ret

haltloop:
    hlt
    jmp haltloop

BOOT_DRIVE db 0x0

cpuid_error_msg db "The CPU does not support CPUID", 0
cpu_error_msg db "Not a 64 bit CPU", 0
disk_error_msg db "Disk error", 0
sector_error_msg db "Sector error", 0
kernel_loading_msg db "Loading kernel", 0
switch_msg db "Switching to 64 bit mode", 0

%include "gdt.asm"

; MBR magic number
times 510 - ($ - $$) db 0
dw 0xaa55

KERNEL_OFFSET:                  ; Memory address where kernel is loaded to.

prepare_long_mode:              ; The kernel technically starts here, but it's
                                ; still bootloader code.

    mov si, switch_msg
    call bios_print

    mov ah, 0x02                ; Move cursor to top left corner of screen.
    mov bh, 0x00
    mov dh, 0x00
    mov dl, 0x00
    int 0x10

    mov ax, 0x2401              ; Due to some short-sighted programmers, the A20
    int 0x15                    ; line is disabled by default on boot. Entering
                                ; long mode without enabling the A20 line will
                                ; result in only odd MiBs of memory being
                                ; accessible.


                                ; Clear the page tables.

    mov edi, 0x1000             ; Address of the PML4 table.
    mov cr3, edi                ; Set cr3 to address of PML4 table.
    xor eax, eax                ; Clear eax.
    mov ecx, 4096               ; Set ecx to number of page table entries.
    rep stosd                   ; Store 4096 0x00000000s to page tables.
    mov edi, cr3

                                ; Set up page table structure.

    mov dword [edi], 0x2003     ; Set the first entry of the PML4 table to
                                ; point to the PDPT table.
    add edi, 0x1000             ; Increase edi to point to the PDPT table.
    mov dword [edi], 0x3003     ; Set the first entry of the PDPT table to
                                ; point to the PD table.
    add edi, 0x1000             ; Increase edi to point to the PD table.
    mov dword [edi], 0x4003     ; Set the first entry of the PD table to point
                                ; to the PT table.
    add edi, 0x1000             ; Increase edi to point to the PT table.

                                ; Set up page table entries. This identity maps
                                ; the first 2 MiB of memory.

    mov ebx, 0x00000003         ; Data to be stored in page table entries:
                                ; Present bit set, read/write bit set.
    mov ecx, 512                ; Number of page table entries to set.

    .set_entry:
        mov dword [edi], ebx    ; Store data in page table entry.
        add ebx, 0x1000         ; Increase ebx by 4096 to increase the physical
                                ; address to be mapped.
        add edi, 8              ; Increase edi to point to the next page table
                                ; entry.
        loop .set_entry

                                ; Enable PAE.

    mov eax, cr4                ; Set PAE bit in cr4.
    or eax, 1 << 5
    mov cr4, eax

                                ; Set LM bit.

    mov ecx, 0xc0000080         ; Read EFER MSR to EAX.
    rdmsr
    or eax, 1 << 8              ; Enable LM bit.
    wrmsr                       ; Write EAX back to EFER MSR.

                                ; Enable paging.

    mov eax, cr0                ; Set both PG and PE bits in cr0.
    or eax, 1 << 31 | 1 << 0
    mov cr0, eax

    cli                         ; Disable interrupts until kernel creates IDT.

    lgdt [gdt_descriptor]       ; Load GDT.

                                ; Set up segment pointers for long mode.

    jmp CODE_SEG:init_long      ; Jump to 64 bit code.

[bits 64]

init_long:
    mov ax, DATA_SEG            ; Move data segment address to ax.
    mov ds, ax                  ; Data segment
    mov ss, ax                  ; Stack segment
    mov es, ax                  ; Extra segment
    mov fs, ax                  ; F segment
    mov gs, ax                  ; G segment

    mov esp, kernel_stack_top   ; Set stack pointer to top of kernel stack.

                                ; Clear screen.

    mov edi, 0xb8000            ; Set destination to VGA memory.
    mov eax, 0x0f20             ; Set eax to white space character.
    mov ecx, 80 * 25            ; Number of characters to clear.
    rep stosd                   ; Repeat store eax to edi ecx times.

    mov esi, kernel_exec_msg
    call vga_print

    [extern kmain]
    call kmain

    cli

    .loop                       ; Loop forever in case kernel returns.
        hlt
        jmp .loop

vga_print:
    mov edi, 0xb8000            ; Set destination to VGA memory.
    mov ah, 0x0f                ; Set attribute to white on black.
    jmp .loop

    .loop:
        lodsb                   ; Load next byte from string into al.
        or al, al               ; Check if al is 0.
        jz .end                 ; If al is 0, end of string reached.
        stosw                   ; Store al in VGA memory.
        jmp .loop

    .end:
        ret

kernel_exec_msg db "Executing kernel...", 0

section .bss
align 4                         ; Align to 4 bytes.
kernel_stack_bottom: equ $      ; Set kernel stack bottom to current address.
    resb 16384                  ; Reserve 16KB for kernel stack.
kernel_stack_top:               ; Set kernel stack top to current address.
