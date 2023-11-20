; Before the CPU can exit real mode, the memory needs to be segmented. This is
; done by creating a Global Descriptor Table (GDT) and loading it into the GDTR
; register. The GDT is a table of segment descriptors, which describe the
; properties of a segment.

; More info: https://wiki.osdev.org/Global_Descriptor_Table

; Access bits
PRESENT         equ 1 << 7      ; Segment is present in memory.
NOT_SYS         equ 1 << 4      ; Segment is not a system segment.
EXEC            equ 1 << 3      ; Segment is executable.
RW              equ 1 << 1      ; Readable bit:
                                ; 0 = segment is read-only
                                ; 1 = segment is read/write

; Flags bits
GRAN_4K         equ 1 << 7      ; Granularity bit:
                                ; 0 = limit is in bytes
                                ; 1 = limit is in 4KiB blocks
SZ_32           equ 1 << 6      ; Size bit:
                                ; 0 = 16-bit protected mode
                                ; 1 = 32-bit protected mode
LONG_MODE       equ 1 << 5      ; Long mode bit.

; The GDT needs to start with a null descriptor, an empty segment descriptor.
gdt_start:
    dq 0x0

; Code segment
; This holds the kernel code.
gdt_code:
    dd 0xffff                           ; Limit (low) and base address (low)
    db 0                                ; Base address (mid)
    db PRESENT | NOT_SYS | EXEC | RW    ; Access bits
    db GRAN_4K | LONG_MODE | 0xf        ; Flags bits and limit (high)
    db 0                                ; Base address (high)

; Data segment
; This will hold the stack, data and other segments.
gdt_data:
    dd 0xffff                           ; Limit (low) and base address (low)
    db 0                                ; Base address (mid)
    db PRESENT | NOT_SYS | RW           ; Access bits
    db GRAN_4K | SZ_32 | 0xf            ; Flags bits and limit (high)
    db 0                                ; Base address (high)

align 8                                 ; Align the GDT to 4 bytes
    dw 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
