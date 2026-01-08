; ============================================
; MINIMAL TEST - DEBUG LEDS ONLY
; ============================================

.setcpu "6502"
.export start

LEDS = $C001

.segment "STARTUP"

start:
    sei             ; Disable interrupts
    cld             ; Clear decimal mode
    
    ; DEBUG: Turn ON all LEDs (Assuming Active Low 0)
    lda #$00
    sta LEDS
    
    ; Infinite Loop
inf:
    jmp inf
