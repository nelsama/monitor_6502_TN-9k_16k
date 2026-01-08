; ============================================
; CALABOZO DEL TERROR v2.0
; Juego de Aventura de Texto para 6502 Monitor
; ============================================

.setcpu "6502"
.export start

; --- HARDWARE ---
UART_DATA    = $C020
UART_STATUS  = $C021
LEDS         = $C001

; --- ZERO PAGE VARIABLES ---
ptr          = $E0      ; Puntero general (2 bytes)
room         = $E2      ; Habitacion actual (1 byte)
cmd_idx      = $E3      ; Indice buffer comando
char         = $E4      ; Caracter temporal

; --- BUFFERS ---
CMD_BUFFER   = $0300    ; Buffer para entrada de usuario (Pagina 3)

.segment "STARTUP"

start:
    sei                 ; Deshabilitar interrupciones (CRITICO)
    cld                 ; Modo binario
    
    ; Inicializar estado
    lda #0
    sta room            ; Empezar en habitacion 0 (Entrada)
    
    ; Mensaje de bienvenida
    lda #<msg_intro
    sta ptr
    lda #>msg_intro
    sta ptr+1
    jsr puts

    ; Mostrar ayuda inicial
    jsr cmd_help
    
    ; Loop principal del juego
game_loop:
    jsr print_room      ; Mostrar descripcion habitacion
    
input_loop:
    jsr prompt          ; Mostrar prompt >
    jsr get_line        ; Leer linea de comando
    jsr parse_cmd       ; Interpretar comando
    jmp game_loop       ; Repetir

; ============================================
; RUTINAS DEL JUEGO
; ============================================

; --- PARSE COMMAND ---
; Interpreta el buffer de comando
parse_cmd:
    ; Comando vacio?
    lda CMD_BUFFER
    beq @exit
    
    ; Primer caracter es el comando
    ldx CMD_BUFFER
    
    ; Normalizar a mayusculas (a-z -> A-Z)
    cpx #'a'
    bcc @check_cmds
    cpx #'z'
    bcs @check_cmds
    txa
    sec
    sbc #32
    tax
    
@check_cmds:
    ; Norte
    cpx #'N'
    beq cmd_north
    
    ; Sur
    cpx #'S'
    beq cmd_south
    
    ; Este
    cpx #'E'
    beq cmd_east
    
    ; Oeste
    cpx #'W'
    beq cmd_west
    
    ; Mirar (Look)
    cpx #'L'
    beq cmd_look
    
    ; Ayuda
    cpx #'H'
    beq cmd_help
    
    ; Desconocido
    lda #<msg_unknown
    sta ptr
    lda #>msg_unknown
    sta ptr+1
    jsr puts
@exit:
    rts

; --- MOVIMIENTOS ---
cmd_north:
    ldx room
    lda map_n,x
    jmp move_player
    
cmd_south:
    ldx room
    lda map_s,x
    jmp move_player

cmd_east:
    ldx room
    lda map_e,x
    jmp move_player

cmd_west:
    ldx room
    lda map_w,x
    jmp move_player

move_player:
    cmp #$FF            ; Hay salida?
    beq @blocked
    sta room            ; Cambiar habitacion
    rts
@blocked:
    lda #<msg_blocked
    sta ptr
    lda #>msg_blocked
    sta ptr+1
    jsr puts
    rts

cmd_look:
    rts                 ; game_loop reimprime la room automaticamente

cmd_help:
    lda #<msg_help
    sta ptr
    lda #>msg_help
    sta ptr+1
    jsr puts
    rts

; --- ROOM DISPLAY ---
print_room:
    jsr crlf
    
    ; Imprimir titulo "HABITACION X"
    lda #<msg_room
    sta ptr
    lda #>msg_room
    sta ptr+1
    jsr puts
    
    lda room
    clc
    adc #'0'            ; Convertir numero a ASCII
    jsr putc
    jsr crlf
    jsr crlf
    
    ; Buscar descripcion en tabla
    ; (Calculo simple: room * 2 para indexar tabla de punteros)
    lda room
    asl a               ; A = room * 2
    tax
    lda room_desc_table,x
    sta ptr
    lda room_desc_table+1,x
    sta ptr+1
    jsr puts
    rts

; --- INPUT LINE ---
; Lee una linea hasta ENTER y la guarda en CMD_BUFFER
get_line:
    ldx #0
@loop:
    jsr getc
    
    ; Echo
    jsr putc
    
    ; Enter?
    cmp #13
    beq @done
    cmp #10
    beq @done
    
    ; Guardar si hay espacio
    cpx #30
    bcs @loop
    sta CMD_BUFFER,x
    inx
    jmp @loop
    
@done:
    lda #0
    sta CMD_BUFFER,x    ; Terminar con null
    jsr crlf
    rts

; --- UTILS ---
prompt:
    lda #13
    jsr putc
    lda #10
    jsr putc
    lda #'>'
    jsr putc
    lda #' '
    jsr putc
    rts

crlf:
    lda #13
    jsr putc
    lda #10
    jsr putc
    rts

puts:
    ldy #0
@loop:
    lda (ptr),y
    beq @done
    jsr putc
    iny
    jmp @loop
@done:
    rts

putc:
    pha
@wait:
    lda UART_STATUS
    and #$01        ; TX Ready?
    beq @wait
    pla
    sta UART_DATA
    rts

getc:
@wait:
    lda UART_STATUS
    and #$02        ; RX Valid?
    beq @wait
    lda UART_DATA
    rts

; ============================================
; DATOS DEL JUEGO
; ============================================

.segment "RODATA"

; --- MAPA (0=start, 1=hall, 2=dungeon, 3=treasure, 4=trap) ---
; FF = Bloqueado
;     [3]
;      |
; [4]-[1]-[2]
;      |
;     [0]

map_n: .byte 1, 3, $FF, $FF, $FF
map_s: .byte $FF, 0, $FF, 1, $FF
map_e: .byte $FF, 2, $FF, $FF, 1
map_w: .byte $FF, 4, 1, $FF, $FF

; --- TEXTOS ---
msg_intro:
    .byte "*********************************", 13, 10
    .byte "*     CALABOZO DEL TERROR v2    *", 13, 10
    .byte "*********************************", 13, 10
    .byte 13, 10
    .byte "Te encuentras atrapado en un", 13, 10
    .byte "calabozo oscuro y frio...", 0

msg_room:
    .byte "HABITACION ", 0

msg_blocked:
    .byte "No puedes ir por ahi.", 13, 10, 0

msg_unknown:
    .byte "No entiendo ese comando.", 13, 10, 0

msg_help:
    .byte "Comandos: N, S, E, W, L (Look), H (Help)", 13, 10, 0

; Descripciones
room0_desc: .byte "Estas en la ENTRADA. Una puerta oscura esta al NORTE.", 0
room1_desc: .byte "Estas en el GRAN SALON. Pasillos van al NORTE, ESTE y OESTE. Al SUR esta la salida.", 0
room2_desc: .byte "Es una PRISON humeda. Cadenas cuelgan de las paredes. Solo puedes volver al OESTE.", 0
room3_desc: .byte "Has encontrado la SALA DEL TESORO! Monedas de oro por todas partes! (FIN)", 0
room4_desc: .byte "Es una TRAMPA! El suelo esta lleno de pinchos. Cuidado! Vuelve al ESTE.", 0

; Tabla de punteros a descripciones
room_desc_table:
    .word room0_desc
    .word room1_desc
    .word room2_desc
    .word room3_desc
    .word room4_desc
