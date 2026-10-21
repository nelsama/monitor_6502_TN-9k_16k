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

; Variables en zero page: declararlas con .exportzp/.importzp permite que
; ca65 use direccionamiento de pagina cero (2 bytes) en lugar de absoluto
; (3 bytes). Se exportan aqui y se re-importan mas abajo.

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
; Variables temporales en ZP
; ============================================
; Nombres propios (sptr1/sptr2/scount) para no chocar con ptr1/ptr2 que
; cc65 ya define en la zero page y que romapi.s importa.
;
; Se declaran AQUI, antes del segmento CODE, para que ca65 conozca su
; naturaleza de pagina cero al ensamblar las instrucciones que las usan:
; emite $85 xx (2 bytes) en vez de $8D xx xx (3 bytes). Misma direccion y
; mismo efecto en runtime.
.segment "ZEROPAGE"
sptr1:   .res 2
sptr2:   .res 2
scount:  .res 2

.exportzp sptr1, sptr2, scount

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
    sta sptr1
    lda #>__DATA_LOAD__
    sta sptr1+1
    
    lda #<__DATA_RUN__
    sta sptr2
    lda #>__DATA_RUN__
    sta sptr2+1
    
    ; Contador de bytes
    lda #<__DATA_SIZE__
    sta scount
    lda #>__DATA_SIZE__
    sta scount+1
    
    ldy #0
@loop:
    lda (sptr1),y
    sta (sptr2),y
    
    ; Incrementar punteros
    iny
    bne @check
    inc sptr1+1
    inc sptr2+1
    
@check:
    ; Decrementar contador
    lda scount
    bne @dec_lo
    lda scount+1
    beq @done
    dec scount+1
@dec_lo:
    dec scount
    
    ; Verificar si terminamos
    lda scount
    ora scount+1
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
    sta sptr1
    lda #>__BSS_RUN__
    sta sptr1+1
    
    lda #<__BSS_SIZE__
    sta scount
    lda #>__BSS_SIZE__
    sta scount+1
    
    ldy #0
    lda #0
@loop:
    sta (sptr1),y
    
    iny
    bne @check
    inc sptr1+1
    
@check:
    ; Decrementar contador
    ldx scount
    bne @dec_lo
    ldx scount+1
    beq @done
    dec scount+1
@dec_lo:
    dec scount
    
    ldx scount
    bne @loop
    ldx scount+1
    bne @loop
    
@done:
    rts
