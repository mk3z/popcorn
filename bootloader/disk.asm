disk_load:
    mov dh, 3                   ; Set sector count.
    push dx                     ; Save dx as last because it will be used later
                                ; to check if all sectors were read.

    mov ah, 0x02                ; Read mode
    mov al, dh                  ; Number of sectors
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

    ret

disk_error:
    mov si, disk_error_msg
    call bios_print
    hlt

sector_error:
    mov si, sector_error_msg
    call bios_print
    hlt

disk_error_msg db "Disk error", 0
sector_error_msg db "Sector error", 0
