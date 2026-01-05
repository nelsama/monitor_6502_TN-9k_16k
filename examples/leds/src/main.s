; ============================================================================
; main.s - Plantilla de programa en ensamblador para Monitor 6502
; ============================================================================
; Este programa se carga en RAM y se ejecuta desde el monitor con:
;   LOAD nombre.bin 0400
;   G 0400
;
; Características:
;   - Dirección de carga: $0400
;   - Usa Zero Page $20-$3F (no conflictúa con el monitor)
;   - Stack del 6502: $0100-$01FF (compartido con monitor)
; ============================================================================

.segment "STARTUP"

; ============================================================================
; CONSTANTES DE HARDWARE
; ============================================================================
LEDS    = $C001         ; Puerto de LEDs (active low)
; PORT1   = $C000       ; Puerto de salida 1
; CFG1    = $C002       ; Configuración puerto 1
; CFG2    = $C003       ; Configuración puerto 2

; ============================================================================
; VARIABLES EN ZERO PAGE (usar $20-$3F para no conflictuar con monitor)
; ============================================================================
led     = $20           ; LED actual
temp    = $21           ; Variable temporal
count   = $22           ; Contador general

; ============================================================================
; PUNTO DE ENTRADA - El programa inicia aquí ($0400)
; ============================================================================
start:
    ; Inicialización
    jsr init
    
    ; Bucle principal
main_loop:
    jsr effect_knight_rider
    jmp main_loop

; ============================================================================
; INICIALIZACIÓN
; ============================================================================
init:
    ; Apagar todos los LEDs al inicio
    lda #$FF
    sta LEDS
    rts

; ============================================================================
; EFECTO: KNIGHT RIDER (luz que va y viene)
; ============================================================================
effect_knight_rider:
    ; Ida: bit 0 -> bit 5 (derecha a izquierda)
    lda #$01
    sta led
    
@go_left:
    ; Mostrar LED (lógica negativa: 0=encendido)
    lda led
    eor #$FF
    sta LEDS
    
    ; Delay
    jsr delay_long
    
    ; Siguiente LED
    asl led
    lda led
    cmp #$40            ; ¿Llegó al bit 6?
    bne @go_left
    
    ; Vuelta: bit 5 -> bit 0 (izquierda a derecha)
    lda #$20
    sta led
    
@go_right:
    ; Mostrar LED
    lda led
    eor #$FF
    sta LEDS
    
    ; Delay
    jsr delay_long
    
    ; Siguiente LED
    lsr led
    lda led
    bne @go_right       ; ¿Llegó a 0?
    
    rts

; ============================================================================
; EFECTO: PARPADEO TODOS LOS LEDS
; ============================================================================
effect_blink:
    ldx #$05            ; 5 repeticiones
    
@loop:
    ; Encender todos
    lda #$00
    sta LEDS
    jsr delay_long
    
    ; Apagar todos
    lda #$FF
    sta LEDS
    jsr delay_long
    
    dex
    bne @loop
    rts

; ============================================================================
; EFECTO: CONTADOR BINARIO
; ============================================================================
effect_counter:
    lda #$00
    sta count
    
@loop:
    ; Mostrar valor (invertido por lógica negativa)
    lda count
    eor #$FF
    sta LEDS
    
    jsr delay_long
    
    inc count
    lda count
    cmp #$40            ; Contar hasta 64
    bne @loop
    
    rts

; ============================================================================
; SUBRUTINA: DELAY LARGO (~0.5 segundos a 3.375 MHz)
; ============================================================================
delay_long:
    ldx #$30            ; Bucle externo (ajustar para velocidad)
@outer:
    ldy #$00            ; Bucle interno (256 iteraciones)
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

; ============================================================================
; SUBRUTINA: DELAY CORTO
; ============================================================================
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
