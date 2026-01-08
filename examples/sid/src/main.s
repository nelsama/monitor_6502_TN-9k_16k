; ============================================================================
; main.s - Demo Polifonico SID + LEDs para Monitor 6502
; ============================================================================
; Efectos polifonicos con 3 voces del SID y LEDs sincronizados
; Usa timer hardware para delays precisos
; LOAD SID / G 0800
; ============================================================================

.setcpu "6502"
.segment "STARTUP"
.export start

; ============================================================================
; HARDWARE
; ============================================================================
SID_BASE        = $D400

; Voz 1
SID_V1_FREQ_LO  = $D400
SID_V1_FREQ_HI  = $D401
SID_V1_PW_LO    = $D402
SID_V1_PW_HI    = $D403
SID_V1_CTRL     = $D404
SID_V1_AD       = $D405
SID_V1_SR       = $D406

; Voz 2
SID_V2_FREQ_LO  = $D407
SID_V2_FREQ_HI  = $D408
SID_V2_PW_LO    = $D409
SID_V2_PW_HI    = $D40A
SID_V2_CTRL     = $D40B
SID_V2_AD       = $D40C
SID_V2_SR       = $D40D

; Voz 3
SID_V3_FREQ_LO  = $D40E
SID_V3_FREQ_HI  = $D40F
SID_V3_PW_LO    = $D410
SID_V3_PW_HI    = $D411
SID_V3_CTRL     = $D412
SID_V3_AD       = $D413
SID_V3_SR       = $D414

; Filtro y control global
SID_FC_LO       = $D415
SID_FC_HI       = $D416
SID_RES_FILT    = $D417
SID_MODE_VOL    = $D418

LEDS            = $C001

; Timer hardware
TIMER_USEC_0    = $C038
TIMER_USEC_1    = $C039
TIMER_USEC_2    = $C03A
TIMER_USEC_3    = $C03B
TIMER_LATCH_CTL = $C03C
LATCH_USEC      = $02

; Control SID - Waveforms
GATE_ON         = $01
WAVE_TRI        = $10
WAVE_SAW        = $20
WAVE_PULSE      = $40
WAVE_NOISE      = $80

; ============================================================================
; VARIABLES (Zero Page)
; ============================================================================
.segment "ZEROPAGE": zeropage
temp:           .res 1
count:          .res 1
led_pat:        .res 1
freq_lo:        .res 1
freq_hi:        .res 1
note_idx:       .res 1
delay_ms_lo:    .res 1      ; Milisegundos para delay
delay_ms_hi:    .res 1
timer_start:    .res 4      ; Tiempo inicial (32-bit)
timer_target:   .res 4      ; Tiempo objetivo

; ============================================================================
; CODIGO
; ============================================================================
.segment "STARTUP"

start:
    sei
    cld
    jsr sid_init
    
main_loop:
    ; Efecto 1: Barrido simple
    jsr effect_sweep
    
    ; Efecto 2: Acordes
    jsr effect_chords
    
    ; Efecto 3: Arpegio
    jsr effect_arpeggio
    
    ; Efecto 4: Sirena
    jsr effect_siren
    
    ; Repetir
    jmp main_loop

; ============================================================================
; INICIALIZAR SID
; ============================================================================
sid_init:
    ; Limpiar todos los registros
    ldx #$18
    lda #$00
@clear:
    sta SID_BASE,x
    dex
    bpl @clear
    
    ; Volumen maximo
    lda #$0F
    sta SID_MODE_VOL
    
    ; ADSR rapido para escuchar cambios
    ; Attack=0, Decay=0, Sustain=15, Release=1
    lda #$00            ; A=0, D=0 (inmediato)
    sta SID_V1_AD
    sta SID_V2_AD
    sta SID_V3_AD
    lda #$F1            ; S=15 (max), R=1 (rapido)
    sta SID_V1_SR
    sta SID_V2_SR
    sta SID_V3_SR
    
    ; Pulse width 50%
    lda #$08
    sta SID_V1_PW_HI
    sta SID_V2_PW_HI
    sta SID_V3_PW_HI
    
    ; LEDs apagados
    lda #$FF
    sta LEDS
    rts

; ============================================================================
; EFECTO 1: BARRIDO DE FRECUENCIA (una voz)
; ============================================================================
effect_sweep:
    ; Frecuencia inicial baja
    lda #$00
    sta freq_lo
    lda #$10            ; Empezar en $1000
    sta freq_hi
    
    lda #$01
    sta led_pat
    
@sweep_up:
    ; Cargar frecuencia
    lda freq_lo
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    ; Gate ON + Sawtooth
    lda #WAVE_SAW | GATE_ON
    sta SID_V1_CTRL
    
    ; LED
    lda led_pat
    eor #$FF
    sta LEDS
    
    jsr delay_short
    
    ; Incrementar frecuencia
    lda freq_lo
    clc
    adc #$80            ; Subir rapido
    sta freq_lo
    lda freq_hi
    adc #$00
    sta freq_hi
    
    ; Rotar LED
    asl led_pat
    lda led_pat
    cmp #$40
    bcc @no_wrap
    lda #$01
    sta led_pat
@no_wrap:
    
    ; Hasta $6000
    lda freq_hi
    cmp #$60
    bcc @sweep_up
    
    ; Barrido descendente
@sweep_down:
    lda freq_lo
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    jsr delay_short
    
    ; Decrementar frecuencia
    lda freq_lo
    sec
    sbc #$80
    sta freq_lo
    lda freq_hi
    sbc #$00
    sta freq_hi
    
    ; Hasta $1000
    lda freq_hi
    cmp #$10
    bcs @sweep_down
    
    ; Gate OFF
    lda #WAVE_SAW
    sta SID_V1_CTRL
    
    lda #$FF
    sta LEDS
    jsr delay_med
    rts

; ============================================================================
; EFECTO 2: ACORDES (3 voces simultaneas)
; ============================================================================
effect_chords:
    lda #0
    sta note_idx        ; Usar variable para el indice
    
@chord_loop:
    ldx note_idx
    
    ; Verificar fin
    lda chord_lo,x
    beq @chords_done
    
    ; Voz 1: Fundamental
    sta SID_V1_FREQ_LO
    lda chord_hi,x
    sta SID_V1_FREQ_HI
    
    ; Voz 2: Tercera (siguiente nota)
    lda chord_lo+1,x
    sta SID_V2_FREQ_LO
    lda chord_hi+1,x
    sta SID_V2_FREQ_HI
    
    ; Voz 3: Quinta
    lda chord_lo+2,x
    sta SID_V3_FREQ_LO
    lda chord_hi+2,x
    sta SID_V3_FREQ_HI
    
    ; Gate ON las 3 voces con Pulse
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    sta SID_V2_CTRL
    sta SID_V3_CTRL
    
    ; LED segun acorde
    lda note_idx
    lsr a               ; /2
    and #$03
    tax
    lda led_table,x
    sta LEDS
    
    jsr delay_long
    jsr delay_long
    
    ; Gate OFF (release)
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    sta SID_V2_CTRL
    sta SID_V3_CTRL
    
    jsr delay_short
    
    ; Siguiente acorde (3 notas por acorde)
    lda note_idx
    clc
    adc #3
    sta note_idx
    cmp #12             ; 4 acordes x 3 notas
    bcc @chord_loop
    
@chords_done:
    lda #$FF
    sta LEDS
    jsr delay_med
    rts

; ============================================================================
; EFECTO 3: ARPEGIO RAPIDO
; ============================================================================
effect_arpeggio:
    lda #4              ; 4 repeticiones
    sta count
    
@arp_rep:
    lda #0
    sta note_idx
    
@arp_loop:
    ldx note_idx
    cpx #6
    bcs @arp_next       ; Si X >= 6, siguiente rep
    
    ; Cargar nota
    lda arp_lo,x
    sta SID_V1_FREQ_LO
    lda arp_hi,x
    sta SID_V1_FREQ_HI
    
    ; Gate ON
    lda #WAVE_PULSE | GATE_ON
    sta SID_V1_CTRL
    
    ; LED
    lda led_table,x
    sta LEDS
    
    jsr delay_short
    
    ; Gate OFF
    lda #WAVE_PULSE
    sta SID_V1_CTRL
    
    ; Siguiente nota
    inc note_idx
    jmp @arp_loop
    
@arp_next:
    dec count
    bne @arp_rep
    
    lda #$FF
    sta LEDS
    jsr delay_med
    rts

; ============================================================================
; EFECTO 4: SIRENA (frecuencia oscilante)
; ============================================================================
effect_siren:
    lda #4              ; 4 ciclos
    sta count
    
@siren_loop:
    ; Subir
    lda #$00
    sta freq_lo
    lda #$20
    sta freq_hi
    
@siren_up:
    lda freq_lo
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    lda #WAVE_TRI | GATE_ON
    sta SID_V1_CTRL
    
    ; LED alternante
    lda freq_hi
    and #$10
    beq @led_a
    lda #$F0
    jmp @led_done
@led_a:
    lda #$0F
@led_done:
    sta LEDS
    
    ; Mini delay 10ms
    lda #10
    sta delay_ms_lo
    lda #0
    sta delay_ms_hi
    jsr delay_ms
    
    ; Incrementar
    lda freq_lo
    clc
    adc #$40
    sta freq_lo
    lda freq_hi
    adc #$00
    sta freq_hi
    
    cmp #$40
    bcc @siren_up
    
    ; Bajar
@siren_down:
    lda freq_lo
    sta SID_V1_FREQ_LO
    lda freq_hi
    sta SID_V1_FREQ_HI
    
    ; LED
    lda freq_hi
    and #$10
    beq @led_b
    lda #$F0
    jmp @led_done2
@led_b:
    lda #$0F
@led_done2:
    sta LEDS
    
    ; Mini delay usando timer
    lda #5
    sta delay_ms_lo
    lda #0
    sta delay_ms_hi
    jsr delay_ms
    
    lda freq_lo
    sec
    sbc #$40
    sta freq_lo
    lda freq_hi
    sbc #$00
    sta freq_hi
    
    cmp #$20
    bcs @siren_down
    
    dec count
    bne @siren_loop
    
    ; Gate OFF
    lda #WAVE_TRI
    sta SID_V1_CTRL
    
    lda #$FF
    sta LEDS
    jsr delay_med
    rts

; ============================================================================
; DELAYS usando Timer Hardware ($C038-$C03C)
; El timer cuenta microsegundos automaticamente
; ============================================================================

; delay_ms - Delay en milisegundos
; Entrada: delay_ms_lo/delay_ms_hi = milisegundos a esperar
delay_ms:
    ; Latch para leer tiempo actual
    lda #LATCH_USEC
    sta TIMER_LATCH_CTL
    
    ; Leer microsegundos actuales (32-bit)
    lda TIMER_USEC_0
    sta timer_start
    lda TIMER_USEC_1
    sta timer_start+1
    lda TIMER_USEC_2
    sta timer_start+2
    lda TIMER_USEC_3
    sta timer_start+3
    
    ; Calcular target = start + (ms * 1000)
    ; Primero: ms * 1000 = ms * 1024 - ms * 24 ≈ ms << 10
    ; Simplificado: usamos ms * 1024 (shift left 10 bits = shift left 2 bytes + *4)
    ; Mas simple aun: sumamos 1000us por cada ms
    
    ; Copiar start a target
    lda timer_start
    sta timer_target
    lda timer_start+1
    sta timer_target+1
    lda timer_start+2
    sta timer_target+2
    lda timer_start+3
    sta timer_target+3
    
@add_1ms:
    ; Verificar si ms == 0
    lda delay_ms_lo
    ora delay_ms_hi
    beq @wait_loop
    
    ; Sumar 1000 ($03E8) a target
    lda timer_target
    clc
    adc #$E8            ; Low byte de 1000
    sta timer_target
    lda timer_target+1
    adc #$03            ; High byte de 1000
    sta timer_target+1
    lda timer_target+2
    adc #0
    sta timer_target+2
    lda timer_target+3
    adc #0
    sta timer_target+3
    
    ; Decrementar contador ms
    lda delay_ms_lo
    bne @no_borrow
    dec delay_ms_hi
@no_borrow:
    dec delay_ms_lo
    jmp @add_1ms

@wait_loop:
    ; Latch y leer tiempo actual
    lda #LATCH_USEC
    sta TIMER_LATCH_CTL
    
    ; Comparar current >= target (32-bit)
    ; Byte 3 (mas significativo)
    lda TIMER_USEC_3
    cmp timer_target+3
    bcc @wait_loop      ; current < target
    bne @done           ; current > target
    
    ; Byte 2
    lda TIMER_USEC_2
    cmp timer_target+2
    bcc @wait_loop
    bne @done
    
    ; Byte 1
    lda TIMER_USEC_1
    cmp timer_target+1
    bcc @wait_loop
    bne @done
    
    ; Byte 0
    lda TIMER_USEC_0
    cmp timer_target
    bcc @wait_loop

@done:
    rts

; Delays predefinidos
delay_long:             ; 500ms
    lda #<500
    sta delay_ms_lo
    lda #>500
    sta delay_ms_hi
    jmp delay_ms

delay_med:              ; 200ms
    lda #<200
    sta delay_ms_lo
    lda #>200
    sta delay_ms_hi
    jmp delay_ms

delay_short:            ; 80ms
    lda #<80
    sta delay_ms_lo
    lda #>80
    sta delay_ms_hi
    jmp delay_ms

; ============================================================================
; DATOS - Frecuencias correctas para SID
; ============================================================================
.segment "RODATA"

; Frecuencias (16-bit): Valores tipicos para SID ~1MHz
; C4=1024Hz -> $1CD5, E4=1318Hz -> $2419, G4=1568Hz -> $2B50
; C5=2048Hz -> $39AA

; Acordes: C mayor, G mayor, Am, F mayor
; C: C4-E4-G4
; G: G3-B3-D4  
; Am: A3-C4-E4
; F: F3-A3-C4

chord_lo:
    .byte $D5, $19, $50   ; C4, E4, G4 (Do mayor)
    .byte $A8, $45, $D5   ; G3, B3, D4 (Sol mayor)
    .byte $D0, $D5, $19   ; A3, C4, E4 (La menor)
    .byte $64, $D0, $D5   ; F3, A3, C4 (Fa mayor)
    .byte $00             ; Fin

chord_hi:
    .byte $1C, $24, $2B   ; C4, E4, G4
    .byte $0E, $16, $1C   ; G3, B3, D4
    .byte $10, $1C, $24   ; A3, C4, E4
    .byte $0C, $10, $1C   ; F3, A3, C4
    .byte $00

; Arpegio: C4 E4 G4 C5 G4 E4
arp_lo:
    .byte $D5, $19, $50, $AA, $50, $19
arp_hi:
    .byte $1C, $24, $2B, $39, $2B, $24

; Tabla de LEDs
led_table:
    .byte $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F
