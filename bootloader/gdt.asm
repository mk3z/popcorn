; Before the CPU can enter protected mode, the memory needs to be segmented.
; This is done by creating a Global Descriptor Table (GDT) and loading it into
; the GDTR register. The GDT is a table of segment descriptors, which describe
; the properties of a segment.

; The GDT needs to start with a null descriptor, an empty segment descriptor.
gdt_start:
    dq 0x0

; Code segment
; This will hold the code that we want to execute in protected mode, i.e. the
; kernel.
gdt_code:
    dw 0xffff                   ; Limit (segment length) 1/2

    dw 0x0                      ; Base address 1/3

    db 0x0                      ; Base address 2/3

    db 10011010b                ; flags 1/2
                                ; 1 0 0 1 1 0 1 0
                                ; P DPL S E C R A
                                ; P = 1 (Present)
                                ;   Segment is present in memory
                                ; DPL = 00 (Descriptor Privilege Level)
                                ;   Sets the privilege level of the segment to
                                ;   ring 0.
                                ; S = 1 (Type selector)
                                ;   Defines this is a code segment.
                                ; E = 1 (Executable)
                                ;   Code segment is executable.
                                ; C = 0 (Conforming)
                                ;   Code segment is not conforming, i.e. it can
                                ;   only be executed from the privilege level
                                ;   specified in the DPL field.
                                ; R = 1 (Readable)
                                ;   Code segment is readable.
                                ; A = 0 (Accessed)
                                ;   CPU sets this to 1 when the segment is
                                ;   accessed.

    db 11001111b                ; Flags 2/2
                                ; 1 1  0 0   1 1 1 1
                                ; G DB L AVL Limit
                                ; G = 1 (Granularity)
                                ;   Scaling of limit field, set to 1 to scale
                                ;   limit by 4K.
                                ; DB = 1 (Default operation size)
                                ;   32-bit protected mode
                                ; L = 0 (64-bit code segment)
                                ;   Not in long mode.
                                ; AVL = 0 (Available for use by system software)
                                ;   Ignored by CPU, can be used by OS.
                                ; Limit 2/2

    db 0x0                      ; Base address 3/3

; Data segment
; This will hold the stack f
gdt_data:
    dw 0xffff                   ; Limit (segment length) 1/2

    dw 0x0                      ; Base address 1/3

    db 0x0                      ; Base address 2/3

    db 10010010b                ; Flags 1/2
                                ; 1 0 0 1 0 0 1 0
                                ; P DPL S E D W A
                                ; P = 1 (Present)
                                ;   Segment is present in memory
                                ; DPL = 00 (Descriptor Privilege Level)
                                ;   Sets the privilege level of the segment to
                                ;   ring 0.
                                ; S = 1 (Type selector)
                                ;   Defines this is a data segment.
                                ; E = 0 (Executable)
                                ;   Data segment is not executable.
                                ; D = 1 (Direction)
                                ;   Data segment grows down (i.e. stack)
                                ; W = 1 (Writable)
                                ;   Data segment is writable.
                                ; A = 0 (Accessed)
                                ;   CPU sets this to 1 when the segment is
                                ;   accessed.

    db 11001111b                ; Flags 2/2
                                ; 1 1  0 0   1 1 1 1
                                ; G DB L AVL Limit
                                ; G = 1 (Granularity)
                                ;   Scaling of limit field, set to 1 to scale
                                ;   limit by 4K.
                                ; DB = 1 (Default operation size)
                                ;   32-bit protected mode
                                ; L = 0 (64-bit code segment)
                                ;   Not in long mode.
                                ; AVL = 0 (Available for use by system software)
                                ;   Ignored by CPU, can be used by OS.
                                ; Limit 2/2

    db 0x0                      ; Base address 3/3

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
