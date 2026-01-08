; ============================================================================
; main.s - Demo Simple SID + LEDs para Monitor 6502
; ============================================================================
; Efectos de sonido simples con LEDs sincronizados
; LOAD SID.BIN 0400 / G 0400
; ============================================================================

.segment "STARTUP"

; ============================================================================
; HARDWARE
; ============================================================================
SID_BASE    = $D400
SID_V1_FREQ_LO  = $D400
SID_V1_FREQ_HI  = $D401
SID_V1_PW_LO    = $D402
SID_V1_PW_HI    = $D403
SID_V1_CTRL     = $D404
SID_V1_AD       = $D405
SID_V1_SR       = $D406
SID_MODE_VOL    = $D418

LEDS        = $C001

; Control SID
GATE_ON     = $01
WAVE_SAW    = $20
WAVE_PULSE  = $40
WAVE_NOISE  = $80

; ============================================================================
; VARIABLES
; ============================================================================
led         = $20
freq_hi     = $21
count       = $22

; ============================================================================
; INICIO
; ============================================================================
start:
    jsr sid_init
    
main_loop:
    ; Efecto 1: Barrido de frecuencia con LEDs knight rider
    jsr effect_sweep
    
    ; Efecto 2: Notas con parpadeo
    jsr effect_notes
    
    ; Efecto 3: Ruido con LEDs aleatorios
    jsr effect_noise
    
    jmp main_loop

; ============================================================================
; INICIALIZAR SID
; ============================================================================
sid_init:
    ; Limpiar SID
    ldx #$18
    lda #$00
@clear:
    sta SID_BASE,x
    dex
    bpl @clear
    
    ; Volumen máximo
    lda #$0F
    sta SID_MODE_VOL
    
    ; Configurar envolvente
    lda #$00            ; Attack=0, Decay=0
    sta SID_V1_AD
    lda #$F0            ; Sustain=F, Release=0
    sta SID_V1_SR
    
    ; Pulse width 50%
    lda #$08
    sta SID_V1_PW_HI
    
    ; LEDs off
    lda #$FF
    sta LEDS
    rts

; ============================================================================
; EFECTO 1: BARRIDO + KNIGHT RIDER
; ============================================================================
effect_sweep:
    ; Frecuencia inicial
    lda #$04
    sta freq_hi
    
    ; LED inicial
    lda #$01
    sta led
    
    ; Gate ON + Sawtooth
    lda #WAVE_SAW | GATE_ON
    sta SID_V1_CTRL
    
@sweep_up:
    ; Actualizar frecuencia
    lda #$00
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    ; Mostrar LED
    lda led
    eor #$FF
    sta LEDS
    
    ; Delay
    jsr delay_long
    
    ; Incrementar frecuencia
    inc freq_hi
    inc freq_hi
    
    ; Rotar LED izquierda
    asl led
    lda led
    cmp #$40
    bne @no_reset
    lda #$01
    sta led
@no_reset:
    
    ; ¿Llegó al tope?
    lda freq_hi
    cmp #$40
    bcc @sweep_up
    
    ; Barrido descendente
    lda #$20
    sta led
    
@sweep_down:
    lda #$00
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    ; Mostrar LED
    lda led
    eor #$FF
    sta LEDS
    
    jsr delay_long
    
    ; Decrementar frecuencia
    dec freq_hi
    dec freq_hi
    
    ; Rotar LED derecha
    lsr led
    lda led
    bne @no_reset2
    lda #$20
    sta led
@no_reset2:
    
    lda freq_hi
    cmp #$04
    bcs @sweep_down
    
    ; Gate OFF
    lda #WAVE_SAW
    sta SID_V1_CTRL
    
    ; LEDs off
    lda #$FF
    sta LEDS
    jsr delay_long
    rts

; ============================================================================
; EFECTO 2: NOTAS CON PARPADEO
; ============================================================================
effect_notes:
    ldx #$00
    
@note_loop:
    ; Obtener frecuencia de la nota
    lda notes_lo,x
    beq @notes_done
    sta SID_V1_FREQ_LO
    lda notes_hi,x
    sta SID_V1_FREQ_HI
    
    ; Gate ON + Pulse
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    
    ; LED correspondiente
    lda note_leds,x
    eor #$FF
    sta LEDS
    
    ; Duración nota
    jsr delay_long
    jsr delay_long
    
    ; Gate OFF
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    
    ; Pausa entre notas
    lda #$FF
    sta LEDS
    jsr delay_short
    
    inx
    jmp @note_loop
    
@notes_done:
    rts

; ============================================================================
; EFECTO 3: RUIDO + LEDS RANDOM
; ============================================================================
effect_noise:
    ; Configurar ruido
    lda #$0F            ; Attack=0, Decay=F
    sta SID_V1_AD
    lda #$00
    sta SID_V1_SR
    
    lda #$10
    sta SID_V1_FREQ_HI
    
    ldx #$08            ; 8 explosiones
    
@noise_loop:
    stx count
    
    ; Gate ON + Noise
    lda #WAVE_NOISE | GATE_ON
    sta SID_V1_CTRL
    
    ; LED "aleatorio" basado en contador
    txa
    and #$07
    tax
    lda random_leds,x
    sta LEDS
    ldx count
    
    jsr delay_long
    
    ; Gate OFF
    lda #WAVE_NOISE
    sta SID_V1_CTRL
    
    jsr delay_short
    
    dex
    bne @noise_loop
    
    ; Restaurar envolvente
    lda #$00
    sta SID_V1_AD
    lda #$F0
    sta SID_V1_SR
    
    ; LEDs off
    lda #$FF
    sta LEDS
    jsr delay_long
    rts

; ============================================================================
; DELAYS (copiados del ejemplo LEDs que funciona)
; ============================================================================
delay_long:
    ldx #$30            ; Igual que LEDs
@outer:
    ldy #$00
@inner:
    nop
    nop
    nop
    nop
    dey
    bne @inner
    dex
    bne @outer
    rts

delay_short:
    ldx #$10
@outer:
    ldy #$00
@inner:
    dey
    bne @inner
    dex
    bne @outer
    rts

; ============================================================================
; DATOS
; ============================================================================

; Notas: C4, E4, G4, C5 (arpegio de Do mayor)
notes_lo:
    .byte $11, $57, $E1, $22    ; C4, E4, G4, C5
    .byte $E1, $57, $11         ; G4, E4, C4
    .byte $00                   ; Fin
    
notes_hi:
    .byte $11, $15, $18, $22
    .byte $18, $15, $11
    .byte $00

; LED para cada nota
note_leds:
    .byte $01, $02, $04, $08
    .byte $10, $20, $3F

; LEDs "aleatorios" para ruido
random_leds:
    .byte $EA, $D5, $AB, $D5
    .byte $B6, $DB, $ED, $BE
