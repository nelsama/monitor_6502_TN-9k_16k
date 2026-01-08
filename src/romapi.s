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
.import _uart_init
.import _uart_putc
.import _uart_getc
.import _uart_puts
.import _uart_rx_ready
.import _uart_tx_ready
.import _xmodem_receive

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
mfs_open_entry:
    JMP _mfs_open

; $BF09 - mfs_read (params: buffer en AX, len en stack)
mfs_read_entry:
    JMP _mfs_read

; $BF0C - mfs_close
mfs_close_entry:
    JMP _mfs_close

; $BF0F - mfs_get_size
mfs_get_size_entry:
    JMP _mfs_get_size

; $BF12 - mfs_list (params: index en A, info ptr en stack)
mfs_list_entry:
    JMP _mfs_list

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
; TABLA DE VERSIÓN Y MAGIC (al final)
; ---------------------------------------------------------------------------
; Padding hasta $BF50 para futuras expansiones
.res $50 - (* - _romapi_start), $EA   ; Relleno con NOP

; $BF50 - Magic number y versión
romapi_magic:
    .byte "ROMAPI"      ; Magic: "ROMAPI"
    .byte $01           ; Versión major
    .byte $00           ; Versión minor

; ===========================================================================
; FIN ROMAPI
; ===========================================================================
