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
        .export _rom_read_file
        
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
; uint16_t rom_read_file(void *buf, uint16_t len)
; Llama a mfs_read_ext de la ROM API
; Esta versión usa parámetros en ZP fijo ($F0-$F3), no el stack de CC65
;-----------------------------------------------------------------------------
        .importzp sp            ; Software stack del SID Player (en $20)

; Parámetros para mfs_read_ext (en ZP fijo)
EXT_BUF_LO  = $F0
EXT_BUF_HI  = $F1
EXT_LEN_LO  = $F2
EXT_LEN_HI  = $F3

; ROM API dirección
ROMAPI_MFS_READ_EXT = $BF27

.proc _rom_read_file
        ; len viene en A/X, buf está en nuestro software stack (sp en $20+)
        
        ; Guardar len en parámetros fijos
        sta     EXT_LEN_LO
        stx     EXT_LEN_HI
        
        ; Obtener buf de nuestro stack
        ldy     #0
        lda     (sp),y          ; buf low
        sta     EXT_BUF_LO
        iny
        lda     (sp),y          ; buf high
        sta     EXT_BUF_HI
        
        ; Limpiar nuestro stack (consumir el parámetro buf)
        clc
        lda     sp
        adc     #2
        sta     sp
        bcc     :+
        inc     sp+1
:
        ; Llamar a mfs_read_ext de la ROM
        ; Parámetros ya están en $F0-$F3
        jsr     ROMAPI_MFS_READ_EXT
        
        ; Resultado viene en A/X
        rts
.endproc

;-----------------------------------------------------------------------------
; void sid_clear(void)
; Limpia todos los registros del SID (silencia)
; Primero apaga gates, luego limpia todo
;-----------------------------------------------------------------------------
.proc _sid_clear
        ; Primero: apagar gate de las 3 voces (bit 0 = 0)
        lda     #$00
        sta     SID_BASE+4      ; Voz 1 control (gate off)
        sta     SID_BASE+11     ; Voz 2 control (gate off)
        sta     SID_BASE+18     ; Voz 3 control (gate off)
        
        ; Pequeña pausa para que el release termine
        ldx     #$FF
@delay: dex
        bne     @delay
        
        ; Ahora limpiar todos los registros
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
; Usa self-modifying code para hacer JSR a dirección variable
; Parámetros cc65: addr en A/X
;-----------------------------------------------------------------------------
.proc _sid_call
        ; Guardar dirección destino en la instrucción JSR
        sta     jsr_target+1    ; low byte de la dirección
        stx     jsr_target+2    ; high byte de la dirección
        
        ; Ejecutar JSR con la dirección modificada
jsr_target:
        jsr     $FFFF           ; Esta dirección se modifica arriba
        rts
.endproc

;-----------------------------------------------------------------------------
; void sid_init_song(uint16_t addr, uint8_t song)
; Llama a la rutina init del SID con el número de canción en A
; Parámetros: addr en stack, song en A
;-----------------------------------------------------------------------------
        .export _sid_init_song
        
.proc _sid_init_song
        ; song viene en A, guardarla
        pha
        
        ; Obtener addr del stack
        jsr     popax
        sta     init_jsr+1      ; low byte
        stx     init_jsr+2      ; high byte
        
        ; Recuperar número de canción en A
        pla
        
        ; Llamar init con A = número de canción
init_jsr:
        jsr     $FFFF
        rts
.endproc

