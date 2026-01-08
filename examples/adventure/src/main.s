; ============================================
; DUNGEON ADVENTURE - Juego de texto 6502
; ============================================
; Explora la mazmorra, encuentra el tesoro y escapa!
; Comandos: N/S/E/W (mover), L (mirar), I (inventario), H (ayuda)
; Con sonidos SID y efectos de LEDs!

.setcpu "6502"
.smart on

; === HARDWARE ===
UART_DATA   = $C020
UART_STATUS = $C021
TX_READY    = $01
RX_VALID    = $02

LEDS        = $C001

; SID Chip
SID_V1_FREQ_LO  = $D400
SID_V1_FREQ_HI  = $D401
SID_V1_PW_LO    = $D402
SID_V1_PW_HI    = $D403
SID_V1_CTRL     = $D404
SID_V1_AD       = $D405
SID_V1_SR       = $D406
SID_MODE_VOL    = $D418

; Timer
TIMER_USEC_0    = $C038
TIMER_USEC_1    = $C039
TIMER_USEC_2    = $C03A
TIMER_USEC_3    = $C03B
TIMER_LATCH_CTL = $C03C
LATCH_USEC      = $02

; SID Waveforms
GATE_ON         = $01
WAVE_TRI        = $10
WAVE_SAW        = $20
WAVE_PULSE      = $40
WAVE_NOISE      = $80

; === ZERO PAGE ===
.segment "ZEROPAGE": zeropage
ptr:            .res 2      ; Puntero para strings
room:           .res 1      ; Habitacion actual (0-8)
has_key:        .res 1      ; Tiene llave?
has_gold:       .res 1      ; Tiene tesoro?
torch:          .res 1      ; Tiene antorcha?
input_buf:      .res 16     ; Buffer de entrada
delay_ms_lo:    .res 1      ; Para delays
delay_ms_hi:    .res 1
timer_start:    .res 4      ; Timer 32-bit
timer_target:   .res 4
sound_count:    .res 1      ; Contador para sonidos
led_temp:       .res 1      ; Temporal para LEDs

; === CODIGO ===
.segment "STARTUP"
.export start

start:
    sei
    cld
    
    ; Inicializar SID
    jsr sid_init
    
    ; LEDs apagados
    lda #$FF
    sta LEDS
    
    ; Inicializar estado
    lda #0
    sta room        ; Empezar en entrada
    sta has_key
    sta has_gold
    sta torch
    
    ; Sonido de inicio
    jsr sound_start
    
    ; Mostrar intro
    lda #<str_title
    ldx #>str_title
    jsr print_str
    
    ; Mostrar habitacion inicial
    jsr update_leds
    jsr show_room
    
; === LOOP PRINCIPAL ===
main_loop:
    jsr print_prompt
    jsr get_input
    jsr process_cmd
    jmp main_loop

; === SALIR DEL JUEGO ===
exit_game:
    rts

; === MOSTRAR HABITACION ===
show_room:
    jsr newline
    
    ; Calcular puntero a descripcion
    lda room
    asl a           ; x2
    tax
    lda room_table,x
    sta ptr
    lda room_table+1,x
    sta ptr+1
    
    ; Imprimir descripcion
    jsr print_ptr
    jsr newline
    
    ; Mostrar salidas
    jsr show_exits
    rts

; === MOSTRAR SALIDAS ===
show_exits:
    lda #<str_exits
    ldx #>str_exits
    jsr print_str
    
    ; Calcular offset en tabla de salidas
    lda room
    asl a
    asl a           ; x4 (4 direcciones por room)
    tax
    
    ; Norte
    lda exits,x
    cmp #$FF
    beq @no_n
    lda #'N'
    jsr putchar
    lda #' '
    jsr putchar
@no_n:
    ; Sur
    lda exits+1,x
    cmp #$FF
    beq @no_s
    lda #'S'
    jsr putchar
    lda #' '
    jsr putchar
@no_s:
    ; Este
    lda exits+2,x
    cmp #$FF
    beq @no_e
    lda #'E'
    jsr putchar
    lda #' '
    jsr putchar
@no_e:
    ; Oeste
    lda exits+3,x
    cmp #$FF
    beq @no_w
    lda #'W'
    jsr putchar
@no_w:
    jsr newline
    rts

; === PROCESAR COMANDO ===
process_cmd:
    lda input_buf
    
    ; Convertir a mayuscula
    cmp #'a'
    bcc @check
    cmp #'z'+1
    bcs @check
    sec
    sbc #$20
@check:
    
    cmp #'N'
    bne @not_n
    jmp cmd_north
@not_n:
    cmp #'S'
    bne @not_s
    jmp cmd_south
@not_s:
    cmp #'E'
    bne @not_e
    jmp cmd_east
@not_e:
    cmp #'W'
    bne @not_w
    jmp cmd_west
@not_w:
    cmp #'L'
    beq cmd_look
    cmp #'I'
    beq cmd_inv
    cmp #'H'
    beq cmd_help
    cmp #'G'
    bne @not_g
    jmp cmd_get
@not_g:
    cmp #'Q'
    bne @not_q
    jmp cmd_quit
@not_q:
    
    ; Comando desconocido
    lda #<str_unknown
    ldx #>str_unknown
    jsr print_str
    rts

cmd_look:
    jsr show_room
    rts

cmd_help:
    lda #<str_help
    ldx #>str_help
    jsr print_str
    rts

cmd_inv:
    lda #<str_inv
    ldx #>str_inv
    jsr print_str
    
    lda has_key
    beq @no_key
    lda #<str_key
    ldx #>str_key
    jsr print_str
@no_key:
    lda has_gold
    beq @no_gold
    lda #<str_gold
    ldx #>str_gold
    jsr print_str
@no_gold:
    lda torch
    beq @no_torch
    lda #<str_torch
    ldx #>str_torch
    jsr print_str
@no_torch:
    jsr newline
    rts

cmd_get:
    ; Recoger objeto segun habitacion
    lda room
    
    cmp #2          ; Celda tiene llave
    bne @not_key
    lda has_key
    bne @already
    lda #1
    sta has_key
    jsr sound_pickup
    jsr update_leds
    lda #<str_got_key
    ldx #>str_got_key
    jmp print_str
@not_key:
    
    cmp #5          ; Sala tesoro
    bne @not_gold
    lda has_gold
    bne @already
    lda #1
    sta has_gold
    jsr sound_treasure
    jsr update_leds
    lda #<str_got_gold
    ldx #>str_got_gold
    jmp print_str
@not_gold:

    cmp #3          ; Armeria tiene antorcha
    bne @nothing
    lda torch
    bne @already
    lda #1
    sta torch
    jsr sound_pickup
    jsr update_leds
    lda #<str_got_torch
    ldx #>str_got_torch
    jmp print_str

@already:
    jsr sound_error
    lda #<str_already
    ldx #>str_already
    jmp print_str
    
@nothing:
    jsr sound_error
    lda #<str_nothing
    ldx #>str_nothing
    jmp print_str

cmd_quit:
    lda #<str_quit
    ldx #>str_quit
    jsr print_str
    ; Limpiar stack (quitar direccion de retorno de jsr process_cmd)
    ; y salir al monitor
    pla             ; Quitar byte bajo de retorno
    pla             ; Quitar byte alto de retorno
    rts             ; Ahora RTS vuelve al monitor

; === MOVIMIENTO ===
cmd_north:
    ldx #0
    jmp try_move
cmd_south:
    ldx #1
    jmp try_move
cmd_east:
    ldx #2
    jmp try_move
cmd_west:
    ldx #3
    jmp try_move

try_move:
    ; X = direccion (0=N, 1=S, 2=E, 3=W)
    stx led_temp    ; Guardar direccion (usar led_temp, no ptr!)
    
    ; Calcular offset: room*4 + dir
    lda room
    asl a
    asl a
    clc
    adc led_temp
    tax
    
    lda exits,x
    cmp #$FF
    beq @blocked
    
    ; Guardar habitacion destino ANTES de llamar sonidos
    sta sound_count ; Usar temporalmente sound_count
    
    ; Verificar si necesita llave (room 6 -> 5)
    cmp #5
    bne @no_lock
    lda room
    cmp #6
    bne @no_lock
    lda has_key
    bne @no_lock
    jsr sound_locked
    lda #<str_locked
    ldx #>str_locked
    jsr print_str
    rts
@no_lock:
    
    ; Verificar oscuridad (room 4 sin antorcha)
    lda sound_count ; Recuperar destino
    cmp #4
    bne @no_dark
    lda torch
    bne @no_dark
    jsr sound_error
    lda #<str_dark
    ldx #>str_dark
    jsr print_str
    rts
@no_dark:
    
    ; Mover a nueva habitacion ANTES del sonido
    lda sound_count
    sta room
    
    ; Actualizar LEDs
    jsr update_leds
    
    ; Sonido de pasos (ahora room ya está actualizado)
    jsr sound_footsteps
    
    ; Verificar victoria
    lda room
    cmp #8          ; Salida
    bne @no_win
    lda has_gold
    beq @no_win
    jsr sound_victory
    lda #<str_win
    ldx #>str_win
    jsr print_str
@hang_win:
    jmp @hang_win
@no_win:
    
    jsr show_room
    rts
    
@blocked:
    jsr sound_blocked
    lda #<str_blocked
    ldx #>str_blocked
    jsr print_str
    rts

; === UART I/O ===
putchar:
    pha
@wait:
    lda UART_STATUS
    and #TX_READY
    beq @wait
    pla
    sta UART_DATA
    rts

getchar:
    lda UART_STATUS
    and #RX_VALID
    beq getchar
    lda UART_DATA
    rts

newline:
    lda #$0D
    jsr putchar
    lda #$0A
    jsr putchar
    rts

print_prompt:
    jsr newline
    lda #'>'
    jsr putchar
    lda #' '
    jsr putchar
    rts

; Imprimir string en A/X
print_str:
    sta ptr
    stx ptr+1
print_ptr:
    ldy #0
@loop:
    lda (ptr),y
    beq @done
    jsr putchar
    iny
    bne @loop
@done:
    rts

; Leer linea de entrada
get_input:
    ldx #0
@loop:
    jsr getchar
    
    ; Echo
    pha
    jsr putchar
    pla
    
    ; Enter?
    cmp #$0D
    beq @done
    cmp #$0A
    beq @done
    
    ; Guardar
    cpx #14
    bcs @loop       ; Buffer lleno
    sta input_buf,x
    inx
    jmp @loop
    
@done:
    lda #0
    sta input_buf,x ; Null terminar
    jsr newline
    rts

; ============================================
; SONIDOS SID
; ============================================

; Inicializar SID
sid_init:
    ; Limpiar registros
    ldx #$18
    lda #$00
@clear:
    sta $D400,x
    dex
    bpl @clear
    
    ; Volumen maximo
    lda #$0F
    sta SID_MODE_VOL
    
    ; ADSR rapido
    lda #$00            ; A=0, D=0
    sta SID_V1_AD
    lda #$A0            ; S=10, R=0
    sta SID_V1_SR
    
    ; Pulse width
    lda #$08
    sta SID_V1_PW_HI
    rts

; Sonido de inicio del juego
sound_start:
    ; Arpegio ascendente
    lda #$D5
    sta SID_V1_FREQ_LO
    lda #$1C            ; C4
    sta SID_V1_FREQ_HI
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #100
    jsr delay_a_ms
    
    lda #$19
    sta SID_V1_FREQ_LO
    lda #$24            ; E4
    sta SID_V1_FREQ_HI
    lda #100
    jsr delay_a_ms
    
    lda #$50
    sta SID_V1_FREQ_LO
    lda #$2B            ; G4
    sta SID_V1_FREQ_HI
    lda #100
    jsr delay_a_ms
    
    lda #$AA
    sta SID_V1_FREQ_LO
    lda #$39            ; C5
    sta SID_V1_FREQ_HI
    lda #200
    jsr delay_a_ms
    
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    rts

; Sonido de pasos (2 tonos alternados)
sound_footsteps:
    lda #3
    sta sound_count
    
@step_loop:
    ; Paso 1
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$08
    sta SID_V1_FREQ_HI
    lda #WAVE_NOISE | GATE_ON
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    lda #WAVE_NOISE
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    ; Paso 2
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$06
    sta SID_V1_FREQ_HI
    lda #WAVE_NOISE | GATE_ON
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    lda #WAVE_NOISE
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    dec sound_count
    bne @step_loop
    rts

; Sonido de recoger objeto
sound_pickup:
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$20
    sta SID_V1_FREQ_HI
    lda #WAVE_TRI | GATE_ON
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    lda #$40
    sta SID_V1_FREQ_HI
    lda #50
    jsr delay_a_ms
    
    lda #$60
    sta SID_V1_FREQ_HI
    lda #100
    jsr delay_a_ms
    
    lda #WAVE_TRI
    sta SID_V1_CTRL
    rts

; Sonido de tesoro (especial!)
sound_treasure:
    lda #4
    sta sound_count
    
@treasure_loop:
    lda #$AA
    sta SID_V1_FREQ_LO
    lda #$39            ; C5
    sta SID_V1_FREQ_HI
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #80
    jsr delay_a_ms
    
    lda #$50
    sta SID_V1_FREQ_LO
    lda #$4B            ; E5
    sta SID_V1_FREQ_HI
    lda #80
    jsr delay_a_ms
    
    dec sound_count
    bne @treasure_loop
    
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    rts

; Sonido de error / no se puede
sound_error:
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$10
    sta SID_V1_FREQ_HI
    lda #WAVE_SAW | GATE_ON
    sta SID_V1_CTRL
    lda #150
    jsr delay_a_ms
    
    lda #WAVE_SAW
    sta SID_V1_CTRL
    rts

; Sonido de bloqueado
sound_blocked:
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$0C
    sta SID_V1_FREQ_HI
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #100
    jsr delay_a_ms
    
    lda #$08
    sta SID_V1_FREQ_HI
    lda #100
    jsr delay_a_ms
    
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    rts

; Sonido de puerta cerrada
sound_locked:
    ; Sonido metalico
    lda #$00
    sta SID_V1_FREQ_LO
    lda #$30
    sta SID_V1_FREQ_HI
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #30
    jsr delay_a_ms
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    lda #50
    jsr delay_a_ms
    
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #30
    jsr delay_a_ms
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    rts

; Sonido de victoria!
sound_victory:
    ; Fanfarria
    ; C5
    lda #$AA
    sta SID_V1_FREQ_LO
    lda #$39
    sta SID_V1_FREQ_HI
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    lda #150
    jsr delay_a_ms
    
    ; G4
    lda #$50
    sta SID_V1_FREQ_LO
    lda #$2B
    sta SID_V1_FREQ_HI
    lda #150
    jsr delay_a_ms
    
    ; E5
    lda #$50
    sta SID_V1_FREQ_LO
    lda #$4B
    sta SID_V1_FREQ_HI
    lda #150
    jsr delay_a_ms
    
    ; C6 (final largo)
    lda #$54
    sta SID_V1_FREQ_LO
    lda #$73
    sta SID_V1_FREQ_HI
    lda #$FF
    jsr delay_a_ms
    lda #$FF
    jsr delay_a_ms
    
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    rts

; ============================================
; LEDS - Muestran estado del juego
; ============================================
; LED 0-2: Habitacion (binario)
; LED 3: Tiene llave
; LED 4: Tiene antorcha
; LED 5: Tiene oro

update_leds:
    lda room
    and #$07        ; 3 bits bajos = habitacion
    sta led_temp    ; Usar variable propia, NO ptr
    
    ; LED 3 = llave
    lda has_key
    beq @no_key_led
    lda led_temp
    ora #$08
    sta led_temp
@no_key_led:
    
    ; LED 4 = antorcha
    lda torch
    beq @no_torch_led
    lda led_temp
    ora #$10
    sta led_temp
@no_torch_led:
    
    ; LED 5 = oro
    lda has_gold
    beq @no_gold_led
    lda led_temp
    ora #$20
    sta led_temp
@no_gold_led:
    
    ; Invertir (LEDs activos en bajo)
    lda led_temp
    eor #$FF
    sta LEDS
    rts

; ============================================
; DELAY usando Timer
; ============================================
; delay_a_ms - Delay de A milisegundos (maximo 255)
delay_a_ms:
    sta delay_ms_lo
    lda #0
    sta delay_ms_hi
    ; Fall through a delay_ms

delay_ms:
    ; Latch tiempo actual
    lda #LATCH_USEC
    sta TIMER_LATCH_CTL
    
    ; Leer microsegundos
    lda TIMER_USEC_0
    sta timer_start
    lda TIMER_USEC_1
    sta timer_start+1
    lda TIMER_USEC_2
    sta timer_start+2
    lda TIMER_USEC_3
    sta timer_start+3
    
    ; Copiar a target
    lda timer_start
    sta timer_target
    lda timer_start+1
    sta timer_target+1
    lda timer_start+2
    sta timer_target+2
    lda timer_start+3
    sta timer_target+3
    
@add_1ms:
    lda delay_ms_lo
    ora delay_ms_hi
    beq @wait_loop
    
    ; Sumar 1000us
    lda timer_target
    clc
    adc #$E8
    sta timer_target
    lda timer_target+1
    adc #$03
    sta timer_target+1
    lda timer_target+2
    adc #0
    sta timer_target+2
    lda timer_target+3
    adc #0
    sta timer_target+3
    
    lda delay_ms_lo
    bne @no_borrow
    dec delay_ms_hi
@no_borrow:
    dec delay_ms_lo
    jmp @add_1ms

@wait_loop:
    lda #LATCH_USEC
    sta TIMER_LATCH_CTL
    
    lda TIMER_USEC_3
    cmp timer_target+3
    bcc @wait_loop
    bne @delay_done
    
    lda TIMER_USEC_2
    cmp timer_target+2
    bcc @wait_loop
    bne @delay_done
    
    lda TIMER_USEC_1
    cmp timer_target+1
    bcc @wait_loop
    bne @delay_done
    
    lda TIMER_USEC_0
    cmp timer_target
    bcc @wait_loop

@delay_done:
    rts

; ============================================
; DATOS
; ============================================
.segment "RODATA"

; === MAPA DE LA MAZMORRA ===
;
;     [4]Cripta
;      |
; [3]--[1]--[2]Celda
; Arm   |
;     [0]Entrada
;      |
;    [6]Pasillo--[5]Tesoro (cerrada)
;      |
;    [7]Trampa
;      |
;    [8]Salida
;

; Tabla de salidas: N,S,E,W para cada room ($FF = no hay)
exits:
    .byte 1,   6,   $FF, $FF    ; 0: Entrada -> N:Salon S:Pasillo
    .byte 4,   0,   2,   3      ; 1: Gran Salon -> N:Cripta S:Entrada E:Celda W:Armeria
    .byte $FF, $FF, $FF, 1      ; 2: Celda -> W:Salon
    .byte $FF, $FF, 1,   $FF    ; 3: Armeria -> E:Salon
    .byte $FF, 1,   $FF, $FF    ; 4: Cripta -> S:Salon
    .byte $FF, $FF, $FF, 6      ; 5: Tesoro -> W:Pasillo
    .byte 0,   7,   5,   $FF    ; 6: Pasillo -> N:Entrada S:Trampa E:Tesoro(cerrada)
    .byte 6,   8,   $FF, $FF    ; 7: Trampa -> N:Pasillo S:Salida
    .byte 7,   $FF, $FF, $FF    ; 8: Salida -> N:Trampa

; Tabla de punteros a descripciones
room_table:
    .word room0, room1, room2, room3, room4
    .word room5, room6, room7, room8

; === DESCRIPCIONES DE HABITACIONES ===
room0:
    .byte "=== ENTRADA DE LA MAZMORRA ===", $0D, $0A
    .byte "Una puerta oxidada se abre al NORTE.", $0D, $0A
    .byte "Luz tenue entra desde el exterior.", 0

room1:
    .byte "=== GRAN SALON ===", $0D, $0A
    .byte "Antorchas iluminan paredes de piedra.", $0D, $0A
    .byte "Pasillos van al N, E, W. Sur es la entrada.", 0

room2:
    .byte "=== CELDA ABANDONADA ===", $0D, $0A
    .byte "Cadenas oxidadas cuelgan de la pared.", $0D, $0A
    .byte "Una LLAVE brilla en el suelo! (G=coger)", 0

room3:
    .byte "=== ARMERIA ===", $0D, $0A
    .byte "Armas viejas cubren las paredes.", $0D, $0A
    .byte "Una ANTORCHA encendida! (G=coger)", 0

room4:
    .byte "=== CRIPTA OSCURA ===", $0D, $0A
    .byte "Tumbas antiguas. El aire es frio.", $0D, $0A
    .byte "Algo se mueve en las sombras...", 0

room5:
    .byte "*** SALA DEL TESORO! ***", $0D, $0A
    .byte "Monedas de ORO por todas partes!", $0D, $0A
    .byte "El tesoro del rey! (G=coger)", 0

room6:
    .byte "=== PASILLO SECRETO ===", $0D, $0A
    .byte "Un corredor estrecho y humedo.", $0D, $0A
    .byte "La puerta al ESTE tiene cerradura.", 0

room7:
    .byte "!!! SALA DE TRAMPAS !!!", $0D, $0A
    .byte "Pinchos salen del suelo!", $0D, $0A
    .byte "Cuidado al moverte!", 0

room8:
    .byte "=== SALIDA ===", $0D, $0A
    .byte "La luz del sol! Libertad!", 0

; === STRINGS DEL JUEGO ===
str_title:
    .byte $0D, $0A
    .byte "================================", $0D, $0A
    .byte "   DUNGEON ADVENTURE v1.0", $0D, $0A
    .byte "================================", $0D, $0A
    .byte "Encuentra el tesoro y escapa!", $0D, $0A
    .byte "Comandos: N S E W L I G H Q", $0D, $0A
    .byte "================================", $0D, $0A, 0

str_help:
    .byte "--- AYUDA ---", $0D, $0A
    .byte "N/S/E/W = Mover", $0D, $0A
    .byte "L = Mirar", $0D, $0A
    .byte "I = Inventario", $0D, $0A
    .byte "G = Coger objeto", $0D, $0A
    .byte "H = Esta ayuda", $0D, $0A
    .byte "Q = Salir", $0D, $0A, 0

str_exits:
    .byte "Salidas: ", 0

str_blocked:
    .byte "No puedes ir por ahi.", $0D, $0A, 0

str_unknown:
    .byte "No entiendo. Usa H para ayuda.", $0D, $0A, 0

str_inv:
    .byte "Inventario: ", 0

str_key:
    .byte "[Llave] ", 0

str_gold:
    .byte "[Oro] ", 0

str_torch:
    .byte "[Antorcha] ", 0

str_got_key:
    .byte "Coges la LLAVE oxidada!", $0D, $0A, 0

str_got_gold:
    .byte "Coges el ORO! Ahora escapa!", $0D, $0A, 0

str_got_torch:
    .byte "Coges la ANTORCHA encendida!", $0D, $0A, 0

str_already:
    .byte "Ya lo tienes.", $0D, $0A, 0

str_nothing:
    .byte "No hay nada que coger aqui.", $0D, $0A, 0

str_locked:
    .byte "La puerta esta cerrada. Necesitas una llave.", $0D, $0A, 0

str_dark:
    .byte "Esta muy oscuro! Necesitas luz.", $0D, $0A, 0

str_win:
    .byte $0D, $0A
    .byte "********************************", $0D, $0A
    .byte "*   FELICIDADES! GANASTE!     *", $0D, $0A
    .byte "*   Escapaste con el tesoro!  *", $0D, $0A
    .byte "********************************", $0D, $0A, 0

str_quit:
    .byte "Hasta luego, aventurero!", $0D, $0A, 0