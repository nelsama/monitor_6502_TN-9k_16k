; ============================================
; startup.s - Código de inicio para programas de usuario
; ============================================
; Inicializa el runtime CC65 para programas cargados en RAM
; Se ejecuta desde $0800
; ============================================

.export _init
.export __STARTUP__ : absolute = 1

.import _main
.import __BSS_RUN__, __BSS_SIZE__
.importzp sp

; Variables temporales en zero page
.segment "ZEROPAGE"
ptr1:       .res 2
ptr2:       .res 2
count:      .res 2

.segment "STARTUP"

_init:
    ; Deshabilitar interrupciones durante init
    sei
    cld
    
    ; Inicializar stack pointer del 6502
    ldx #$FF
    txs
    
    ; Inicializar stack pointer de CC65 (software stack)
    ; Usar $2DFF como tope del stack (debajo de $2E00)
    lda #<$2DFF
    sta sp
    lda #>$2DFF
    sta sp+1
    
    ; Inicializar BSS a ceros
    jsr zerobss
    
    ; Llamar a main
    jsr _main
    
    ; Si main retorna, volver al monitor (RTS)
    rts

; ============================================
; zerobss - Inicializa BSS a ceros
; ============================================
zerobss:
    ; Verificar si hay BSS que inicializar
    lda #<__BSS_SIZE__
    ora #>__BSS_SIZE__
    beq @done           ; Si tamaño es 0, salir
    
    ; Puntero a BSS
    lda #<__BSS_RUN__
    sta ptr1
    lda #>__BSS_RUN__
    sta ptr1+1
    
    ; Contador
    lda #<__BSS_SIZE__
    sta count
    lda #>__BSS_SIZE__
    sta count+1
    
    lda #0
    ldy #0
@loop:
    sta (ptr1),y
    
    ; Incrementar puntero
    iny
    bne @check
    inc ptr1+1
    
@check:
    ; Decrementar contador
    lda count
    bne @dec_lo
    lda count+1
    beq @done
    dec count+1
@dec_lo:
    dec count
    
    ; Verificar si terminamos
    lda count
    ora count+1
    bne @loop
    
@done:
    rts
