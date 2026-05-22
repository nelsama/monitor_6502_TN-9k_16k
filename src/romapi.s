;; ===========================================================================
;; ROMAPI.S - API de ROM para programas standalone
;; ===========================================================================
;;
;; Jump Table fija en $BF00 para que programas externos puedan llamar
;; funciones de la ROM sin incluir las librerías.
;;
;; Uso desde C:
;;   #define ROM_SD_INIT      ((uint8_t (*)(void))0xBF00)
;;   #define ROM_MFS_MOUNT    ((uint8_t (*)(void))0xBF03)
;;   etc.
;;
;; Uso desde ASM:
;;   JSR $BF00   ; sd_init
;;   JSR $BF03   ; mfs_mount
;;   etc.
;;
;; ===========================================================================

.export _romapi_start

; Importar funciones de las librerías
.import _sd_init
.import _mfs_mount
.import _mfs_open
.import _mfs_read
.import _mfs_read_ext
.import _mfs_close
.import _mfs_get_size
.import _mfs_list
.import _mfs_create
.import _mfs_write
.import _mfs_delete
.import _mfs_format
.import _uart_init
.import _uart_putc
.import _uart_getc
.import _uart_puts
.import _uart_rx_ready
.import _uart_tx_ready
.import _uart_clear_errors
.import _uart_set_baudrate
.import _xmodem_receive
.import _get_micros
.import _delay_us
.import _delay_ms

; Importar funciones SPI
.import _spi_init
.import _spi_select
.import _spi_deselect
.import _spi_transfer
.import _spi_send
.import _spi_receive
.import _spi_busy

; Importar funciones I2C
.import _i2c_init
.import _i2c_start
.import _i2c_stop
.import _i2c_write_byte
.import _i2c_read_byte
.import _i2c_write
.import _i2c_read

; Importar funciones SD Card (lectura/escritura de sectores)
.import _sd_read_sector
.import _sd_write_sector
.import _sd_is_ready
.import _sd_get_type

; Importar runtime de CC65 para manipular stack
.import pushax
.import pusha
.importzp ptr1, ptr2, tmp1

; Buffer temporal para mfs_list_wrap
.export _mfs_list_tmp
_mfs_list_tmp:
    .res    16

; ===========================================================================
; SEGMENTO ROMAPI - Posición fija en $BF00
; ===========================================================================
.segment "ROMAPI"

_romapi_start:

; ---------------------------------------------------------------------------
; FUNCIONES SD CARD (Base: $BF00)
; ---------------------------------------------------------------------------
; $BF00 - sd_init
sd_init_entry:
    JMP _sd_init

; ---------------------------------------------------------------------------
; FUNCIONES MICROFS (Base: $BF03)
; ---------------------------------------------------------------------------
; $BF03 - mfs_mount
mfs_mount_entry:
    JMP _mfs_mount

; $BF06 - mfs_open (param: puntero a nombre en AX)
; Wrapper: name en $F4-$F5 (ZP)
mfs_open_entry:
    JMP mfs_open_wrap

; $BF09 - mfs_read (params: buffer en AX, len en stack)
; Wrapper: buf en $F0-$F1, len en $F2-$F3
mfs_read_entry:
    JMP mfs_read_wrap

; $BF0C - mfs_close
mfs_close_entry:
    JMP _mfs_close

; $BF0F - mfs_get_size
mfs_get_size_entry:
    JMP _mfs_get_size

; $BF12 - mfs_list (params: index en A, info ptr en stack)
; Wrapper: index en $F4, info ptr en $F5-$F6
mfs_list_entry:
    JMP mfs_list_wrap

; ---------------------------------------------------------------------------
; FUNCIONES UART (Base: $BF15)
; ---------------------------------------------------------------------------
; $BF15 - uart_init
uart_init_entry:
    JMP _uart_init

; $BF18 - uart_putc (param: char en A)
uart_putc_entry:
    JMP _uart_putc

; $BF1B - uart_getc (retorna char en A)
uart_getc_entry:
    JMP _uart_getc

; $BF1E - uart_puts (param: puntero string en AX)
uart_puts_entry:
    JMP _uart_puts

; $BF21 - uart_rx_ready (retorna status en A)
uart_rx_ready_entry:
    JMP _uart_rx_ready

; $BF24 - uart_tx_ready (retorna status en A)
uart_tx_ready_entry:
    JMP _uart_tx_ready

; ---------------------------------------------------------------------------
; FUNCIONES ESPECIALES PARA PROGRAMAS EXTERNOS (Base: $BF27)
; ---------------------------------------------------------------------------
; $BF27 - mfs_read_ext: Lee usando parámetros en RAM fija
;         Input: $00F0-$00F1 = buffer ptr, $00F2-$00F3 = len
;         Output: A/X = bytes leídos
mfs_read_ext_entry:
    JMP _mfs_read_ext

; ---------------------------------------------------------------------------
; FUNCIONES XMODEM (Base: $BF2A)
; ---------------------------------------------------------------------------
; $BF2A - xmodem_receive: Recibe archivo por XMODEM
;         Input: A/X = dirección destino (little-endian: A=low, X=high)
;         Output: A/X = bytes recibidos (positivo) o código error (negativo)
xmodem_receive_entry:
    JMP _xmodem_receive

; ---------------------------------------------------------------------------
; FUNCIONES TIMER (Base: $BF2D) - Solo funciones esenciales
; ---------------------------------------------------------------------------
; $BF2D - get_micros (retorna uint32_t en sreg:A:X)
get_micros_entry:
    JMP _get_micros

; $BF30 - delay_us (param: uint16_t en A:X)
delay_us_entry:
    JMP _delay_us

; $BF33 - delay_ms (param: uint16_t en A:X)
delay_ms_entry:
    JMP _delay_ms

; ---------------------------------------------------------------------------
; NUEVAS FUNCIONES UART (Base: $BF36) - Añadidas al final
; ---------------------------------------------------------------------------
; $BF36 - uart_clear_errors (limpia flags de error)
uart_clear_errors_entry:
    JMP _uart_clear_errors

; $BF39 - uart_set_baudrate (param: divisor en A:X)
uart_set_baudrate_entry:
    JMP _uart_set_baudrate

; ---------------------------------------------------------------------------
; NUEVAS FUNCIONES MICROFS - ESCRITURA (Base: $BF3C)
; ---------------------------------------------------------------------------
; $BF3C - mfs_create (param: name ptr in AX, size in stack)
; Wrapper: name ptr en $F4-$F5, size en $F6-$F7
mfs_create_entry:
    JMP mfs_create_wrap

; $BF3F - mfs_write (params: buffer in AX, len in stack)
; Wrapper: buf en $F4-$F5, len en $F6-$F7
mfs_write_entry:
    JMP mfs_write_wrap

; $BF42 - mfs_delete (param: name ptr in AX)
; Wrapper: name en $F4-$F5 (ZP)
mfs_delete_entry:
    JMP mfs_delete_wrap

; $BF45 - mfs_format
mfs_format_entry:
    JMP _mfs_format

; ---------------------------------------------------------------------------
; FUNCIONES SPI (Base: $BF48)
; ---------------------------------------------------------------------------
; $BF48 - spi_init
spi_init_entry:
    JMP _spi_init

; $BF4B - spi_select (param: cs_mask en A)
spi_select_entry:
    JMP _spi_select

; $BF4E - spi_deselect
spi_deselect_entry:
    JMP _spi_deselect

; $BF51 - spi_transfer (param: data en A, retorna byte en A)
spi_transfer_entry:
    JMP _spi_transfer

; $BF54 - spi_send (param: data en A)
spi_send_entry:
    JMP _spi_send

; $BF57 - spi_receive (retorna byte en A)
spi_receive_entry:
    JMP _spi_receive

; $BF5A - spi_busy (retorna status en A)
spi_busy_entry:
    JMP _spi_busy

; ---------------------------------------------------------------------------
; FUNCIONES I2C (Base: $BF5D)
; ---------------------------------------------------------------------------
; $BF5D - i2c_init
i2c_init_entry:
    JMP _i2c_init

; $BF60 - i2c_start (params: device_addr en stack, rw en A)
i2c_start_entry:
    JMP _i2c_start

; $BF63 - i2c_stop
i2c_stop_entry:
    JMP _i2c_stop

; $BF66 - i2c_write_byte (param: data en A, retorna ACK en A)
i2c_write_byte_entry:
    JMP _i2c_write_byte

; $BF69 - i2c_read_byte (param: ack en A, retorna byte en A)
i2c_read_byte_entry:
    JMP _i2c_read_byte

; $BF6C - i2c_write (params en stack, retorna bytes escritos en A)
i2c_write_entry:
    JMP _i2c_write

; $BF6F - i2c_read (params en stack, retorna bytes leidos en A)
i2c_read_entry:
    JMP _i2c_read

; ---------------------------------------------------------------------------
; FUNCIONES SD CARD - Acceso a sectores (Base: $BF72)
; ---------------------------------------------------------------------------
; $BF72 - sd_read_sector (params: sector en stack, buf ptr en AX)
; Wrapper: lee sector de $F0-$F3, buf de $F4-$F5
sd_read_sector_entry:
    JMP _sd_read_sector_wrap

; $BF75 - sd_write_sector (params: sector en stack, buf ptr en AX)
; Wrapper: lee sector de $F0-$F3, buf de $F4-$F5
sd_write_sector_entry:
    JMP _sd_write_sector_wrap

; $BF78 - sd_is_ready (retorna status en A)
sd_is_ready_entry:
    JMP _sd_is_ready

; $BF7B - sd_get_type (retorna tipo SD en A)
sd_get_type_entry:
    JMP _sd_get_type

; Padding hasta $BF84 para futuras expansiones
.res $84 - (* - _romapi_start), $EA   ; Relleno con NOP

; $BF84 - Magic number y versión
romapi_magic:
    .byte "ROMAPI"      ; Magic: "ROMAPI"
        .byte $24           ; VersiÃ³n (major<<4 | minor)

; ---------------------------------------------------------------------------
; WRAPPERS CON ZP FIJO - Para programas externos
; ---------------------------------------------------------------------------
; Estos wrappers leen parÃ¡metros de Zero Page fijo y los pasan al
; stack de CC65 del monitor, permitiendo que programas externos
; llamen funciones que usan stack sin conflictos de sp.

; mfs_read_wrap: buf en $F0-$F1 (stack), len en $F2-$F3 (AX)
mfs_read_wrap:
    lda     $F0
    ldx     $F1
    jsr     pushax      ; push buf (1er param) al stack
    lda     $F2
    ldx     $F3
    jmp     _mfs_read   ; len (2do param) en AX

; mfs_list_wrap: llama a _mfs_list con buffer en BSS.
.segment "CODE"
.import _mfs_list
mfs_list_wrap:
    lda     $F4
    jsr     pusha
    lda     #<(_mfs_list_tmp)
    ldx     #>(_mfs_list_tmp)
    jsr     _mfs_list
    pha
    lda     $F5
    sta     ptr2
    lda     $F6
    sta     ptr2+1
    lda     #<(_mfs_list_tmp)
    sta     ptr1
    lda     #>(_mfs_list_tmp)
    sta     ptr1+1
    ldy     #14
:   lda     (ptr1),y
    sta     (ptr2),y
    dey
    bpl     :-
    pla
    rts
.segment "ROMAPI"

; mfs_write_wrap: buf en $F4-$F5 (stack), len en $F6-$F7 (AX)
mfs_write_wrap:
    lda     $F4
    ldx     $F5
    jsr     pushax      ; push buf (1er param) al stack
    lda     $F6
    ldx     $F7
    jmp     _mfs_write  ; len (2do param) en AX

; sd_read_sector_wrap: sector en $F0-$F3, buf en $F4-$F5
_sd_read_sector_wrap:
    lda     $F0
    ldx     $F1
    jsr     pushax
    lda     $F2
    ldx     $F3
    jsr     pushax
    lda     $F4
    ldx     $F5
    jmp     _sd_read_sector

; sd_write_sector_wrap: sector en $F0-$F3, buf en $F4-$F5
_sd_write_sector_wrap:
    lda     $F0
    ldx     $F1
    jsr     pushax
    lda     $F2
    ldx     $F3
    jsr     pushax
    lda     $F4
    ldx     $F5
    jmp     _sd_write_sector

; mfs_open_wrap: name ptr en $F4-$F5
mfs_open_wrap:
    lda     $F4
    ldx     $F5
    jmp     _mfs_open

; mfs_delete_wrap: name ptr en $F4-$F5
mfs_delete_wrap:
    lda     $F4
    ldx     $F5
    jmp     _mfs_delete

; mfs_create_wrap: name ptr en $F4-$F5 (stack), size en $F6-$F7 (AX)
mfs_create_wrap:
    lda     $F4
    ldx     $F5
    jsr     pushax      ; push name (1er param) al stack
    lda     $F6
    ldx     $F7
    jmp     _mfs_create ; size (2do param) en AX


; ===========================================================================
