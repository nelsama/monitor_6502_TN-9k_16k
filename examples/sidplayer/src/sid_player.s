;-----------------------------------------------------------------------------
; SID_PLAYER.S - Funciones auxiliares ASM para el reproductor SID
;-----------------------------------------------------------------------------
; Funciones de bajo nivel para control del SID y copia de memoria
;-----------------------------------------------------------------------------

        .setcpu "6502"
        .smart  on
        
        .export _sid_clear
        .export _sid_copy_to_memory
        .export _sid_call
        
        .import pushax, popax
        .importzp ptr1, ptr2, tmp1, tmp2

;-----------------------------------------------------------------------------
; Constantes
;-----------------------------------------------------------------------------
SID_BASE        = $D400

;-----------------------------------------------------------------------------
; Código
;-----------------------------------------------------------------------------
        .code

;-----------------------------------------------------------------------------
; void sid_clear(void)
; Limpia todos los registros del SID (silencia)
;-----------------------------------------------------------------------------
.proc _sid_clear
        lda     #$00
        ldx     #$18            ; 25 registros (0-24)
@loop:
        sta     SID_BASE,x
        dex
        bpl     @loop
        rts
.endproc

;-----------------------------------------------------------------------------
; void sid_copy_to_memory(uint8_t *src, uint16_t dest, uint16_t len)
; Copia len bytes desde src a dest
; Parámetros cc65: src en stack, dest en stack, len en A/X
;-----------------------------------------------------------------------------
.proc _sid_copy_to_memory
        ; len viene en A/X
        sta     tmp1            ; len low
        stx     tmp2            ; len high
        
        ; Obtener dest
        jsr     popax
        sta     ptr2            ; dest low
        stx     ptr2+1          ; dest high
        
        ; Obtener src
        jsr     popax
        sta     ptr1            ; src low
        stx     ptr1+1          ; src high
        
        ; Copiar byte por byte
        ldy     #0
@loop:
        ; Verificar si len == 0
        lda     tmp1
        ora     tmp2
        beq     @done
        
        ; Copiar un byte
        lda     (ptr1),y
        sta     (ptr2),y
        
        ; Incrementar punteros
        iny
        bne     @no_inc
        inc     ptr1+1
        inc     ptr2+1
@no_inc:
        
        ; Decrementar len
        lda     tmp1
        bne     @dec_lo
        dec     tmp2
@dec_lo:
        dec     tmp1
        
        jmp     @loop
        
@done:
        rts
.endproc

;-----------------------------------------------------------------------------
; void sid_call(uint16_t addr)
; Llama a una subrutina en la dirección especificada (JSR indirecto)
; Parámetros cc65: addr en A/X
;-----------------------------------------------------------------------------
.proc _sid_call
        ; Guardar dirección en call_addr (self-modifying code area)
        sta     call_addr
        stx     call_addr+1
        
        ; Hacer JSR indirecto via JMP a código auto-modificable
        jsr     do_call
        rts
        
do_call:
        ; Este JMP será modificado con la dirección real
call_addr = * + 1
        jmp     $FFFF           ; Placeholder - se modifica arriba
.endproc

