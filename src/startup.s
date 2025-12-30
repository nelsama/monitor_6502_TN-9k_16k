; ============================================
; startup.s - Código de inicio para 6502
; ============================================
; Este archivo inicializa el sistema antes de main():
;   1. Configura el stack del 6502
;   2. Configura el stack de CC65 (software stack)
;   3. Copia DATA de ROM a RAM (copydata)
;   4. Inicializa BSS a ceros (zerobss)
;   5. Llama a main()
;
; Esto permite usar librerías de cc65 como stdlib, string, etc.
; ============================================

.export _init
.export __STARTUP__ : absolute = 1

.import _main
.import __DATA_LOAD__, __DATA_RUN__, __DATA_SIZE__
.import __BSS_RUN__, __BSS_SIZE__
.importzp sp

.segment "STARTUP"

_init:
    ; Inicializar stack pointer del 6502
    ldx #$FF
    txs
    
    ; Inicializar stack pointer de CC65 (software stack)
    lda #<$3FFF
    sta sp
    lda #>$3FFF
    sta sp+1
    
    ; Copiar DATA de ROM a RAM
    jsr copydata
    
    ; Inicializar BSS a ceros
    jsr zerobss
    
    ; Llamar a main
    jsr _main
    
    ; Si main retorna, loop infinito
@halt:
    jmp @halt

; ============================================
; copydata - Copia DATA de ROM a RAM
; ============================================
.segment "CODE"

copydata:
    ; Verificar si hay datos que copiar
    lda #<__DATA_SIZE__
    ora #>__DATA_SIZE__
    beq @done           ; Si tamaño es 0, salir
    
    ; Inicializar punteros
    lda #<__DATA_LOAD__
    sta ptr1
    lda #>__DATA_LOAD__
    sta ptr1+1
    
    lda #<__DATA_RUN__
    sta ptr2
    lda #>__DATA_RUN__
    sta ptr2+1
    
    ; Contador de bytes
    lda #<__DATA_SIZE__
    sta count
    lda #>__DATA_SIZE__
    sta count+1
    
    ldy #0
@loop:
    lda (ptr1),y
    sta (ptr2),y
    
    ; Incrementar punteros
    iny
    bne @check
    inc ptr1+1
    inc ptr2+1
    
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

; ============================================
; zerobss - Inicializa BSS a ceros
; ============================================
zerobss:
    ; Verificar si hay BSS
    lda #<__BSS_SIZE__
    ora #>__BSS_SIZE__
    beq @done
    
    lda #<__BSS_RUN__
    sta ptr1
    lda #>__BSS_RUN__
    sta ptr1+1
    
    lda #<__BSS_SIZE__
    sta count
    lda #>__BSS_SIZE__
    sta count+1
    
    ldy #0
    lda #0
@loop:
    sta (ptr1),y
    
    iny
    bne @check
    inc ptr1+1
    
@check:
    ; Decrementar contador
    ldx count
    bne @dec_lo
    ldx count+1
    beq @done
    dec count+1
@dec_lo:
    dec count
    
    ldx count
    bne @loop
    ldx count+1
    bne @loop
    
@done:
    rts

; ============================================
; Variables temporales en ZP
; ============================================
.segment "ZEROPAGE"
ptr1:   .res 2
ptr2:   .res 2
count:  .res 2
