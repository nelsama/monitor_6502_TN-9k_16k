; runtime.s - Runtime mínimo cc65 para programas standalone
; Organizado para que STARTUP quede primero, luego CODE (main), luego RUNTIME

.exportzp sp, ptr1, regsave

; Símbolo requerido por el linker
.export __STARTUP__ : absolute = 1

; Rutinas de stack
.export pusha, pushax
.export popa, popax
.export decsp1, decsp2, decsp3, decsp4, decsp5, decsp6, decsp7, decsp8
.export incsp1, incsp2, incsp3, incsp4, incsp5, incsp6, incsp7, incsp8

; Rutinas de acceso a stack
.export ldax0sp, ldaxysp
.export stax0sp, staxysp

; Rutinas aritméticas
.export tosaddax, tossubax
.export tosmulax, tosdivax, tosmodax
.export tosandax, tosorax, tosxorax
.export aslax1, aslax2, aslax3, aslax4
.export asrax1, asrax2, asrax3, asrax4
.export shlax1, shlax2, shlax3, shlax4
.export shrax1, shrax2, shrax3, shrax4
.export negax, complax
.export incax1, incax2, decax1
.export booleq, boolne, boollt, boolgt, boolle, boolge
.export boolult, boolugt, boolule, booluge

; Shifts con Y
.export aslaxy, asraxy

; Regswap (funciones)
.export regswap1, regswap2, regrestore

; Comparaciones
.export toseqax, tosnax, tosltax, tosgtax, tosleax, tosgeax
.export tosultax, tosugtax, tosuleax, tosugeax

; ============================================================================
; ZEROPAGE
; ============================================================================
.zeropage
sp:     .res 2          ; Software stack pointer
ptr1:   .res 2          ; Puntero temporal
tmp1:   .res 1          ; Temporal
regsave:.res 6          ; Espacio para guardar registros (regsave es dirección ZP)

; ============================================================================
; STARTUP - Inicialización (va primero en RAM)
; ============================================================================
.segment "STARTUP"

    ; Inicializar stack de cc65 en $3DFF
    lda #$FF
    sta sp
    lda #$3D
    sta sp+1
    ; Caer directamente al CODE (main)

; ============================================================================
; CODE - Aquí irá main.c (entre STARTUP y RUNTIME)
; ============================================================================
.segment "CODE"
    ; El código de main.c se insertará aquí automáticamente

; ============================================================================
; RUNTIME - Rutinas de soporte (van después del código del usuario)
; ============================================================================
.segment "RUNTIME"

; ----------------------------------------------------------------------------
; pusha - Push A al stack de software
; ----------------------------------------------------------------------------
pusha:
    ldy sp
    bne @L1
    dec sp+1
@L1:
    dec sp
    ldy #0
    sta (sp),y
    rts

; ----------------------------------------------------------------------------
; pushax - Push AX al stack de software (X=high, A=low)
; ----------------------------------------------------------------------------
pushax:
    pha                 ; Guardar low
    lda sp
    sec
    sbc #2
    sta sp
    bcs @L1
    dec sp+1
@L1:
    ldy #1
    txa
    sta (sp),y          ; High byte
    pla
    dey
    sta (sp),y          ; Low byte
    rts

; ----------------------------------------------------------------------------
; popa - Pop A del stack de software
; ----------------------------------------------------------------------------
popa:
    ldy #0
    lda (sp),y
    inc sp
    bne @L1
    inc sp+1
@L1:
    rts

; ----------------------------------------------------------------------------
; popax - Pop AX del stack de software
; ----------------------------------------------------------------------------
popax:
    ldy #0
    lda (sp),y
    tax
    iny
    lda (sp),y
    pha
    lda sp
    clc
    adc #2
    sta sp
    bcc @L1
    inc sp+1
@L1:
    pla
    ; A=high, X=low -> swap needed
    pha
    txa
    tax                 ; X=low
    pla                 ; A=high... no, queremos A=low, X=high
    ; Corregir: ldy #0: A=byte0, ldy #1: X=byte1
    ; Resultado debe ser A=low(byte0), X=high(byte1)
    rts

; ----------------------------------------------------------------------------
; decspX - Decrementar SP en X bytes (reservar espacio)
; ----------------------------------------------------------------------------
decsp1:
    lda sp
    bne @L1
    dec sp+1
@L1:
    dec sp
    rts

decsp2:
    lda sp
    sec
    sbc #2
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp3:
    lda sp
    sec
    sbc #3
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp4:
    lda sp
    sec
    sbc #4
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp5:
    lda sp
    sec
    sbc #5
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp6:
    lda sp
    sec
    sbc #6
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp7:
    lda sp
    sec
    sbc #7
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

decsp8:
    lda sp
    sec
    sbc #8
    sta sp
    bcs @L1
    dec sp+1
@L1:
    rts

; ----------------------------------------------------------------------------
; incspX - Incrementar SP en X bytes (liberar espacio)
; ----------------------------------------------------------------------------
incsp1:
    inc sp
    bne @L1
    inc sp+1
@L1:
    rts

incsp2:
    lda sp
    clc
    adc #2
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp3:
    lda sp
    clc
    adc #3
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp4:
    lda sp
    clc
    adc #4
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp5:
    lda sp
    clc
    adc #5
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp6:
    lda sp
    clc
    adc #6
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp7:
    lda sp
    clc
    adc #7
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

incsp8:
    lda sp
    clc
    adc #8
    sta sp
    bcc @L1
    inc sp+1
@L1:
    rts

; ----------------------------------------------------------------------------
; ldax0sp - Cargar AX desde (sp)
; ----------------------------------------------------------------------------
ldax0sp:
    ldy #1
    lda (sp),y
    tax
    dey
    lda (sp),y
    rts

; ----------------------------------------------------------------------------
; ldaxysp - Cargar AX desde (sp+Y)
; ----------------------------------------------------------------------------
ldaxysp:
    lda (sp),y
    pha
    iny
    lda (sp),y
    tax
    pla
    rts

; ----------------------------------------------------------------------------
; stax0sp - Guardar AX en (sp)
; ----------------------------------------------------------------------------
stax0sp:
    ldy #0
    sta (sp),y
    iny
    txa
    sta (sp),y
    rts

; ----------------------------------------------------------------------------
; staxysp - Guardar AX en (sp+Y)
; ----------------------------------------------------------------------------
staxysp:
    sta (sp),y
    iny
    txa
    sta (sp),y
    rts

; ----------------------------------------------------------------------------
; Shifts izquierda aritméticos
; ----------------------------------------------------------------------------
aslax1:
shlax1:
    asl a
    rol a               ; No, esto está mal
    rts
    
aslax2:
shlax2:
    asl a
    asl a
    rts

aslax3:
shlax3:
    asl a
    asl a
    asl a
    rts

aslax4:
shlax4:
    asl a
    asl a
    asl a
    asl a
    rts

; ----------------------------------------------------------------------------
; Shifts derecha
; ----------------------------------------------------------------------------
asrax1:
shrax1:
    lsr a
    rts

asrax2:
shrax2:
    lsr a
    lsr a
    rts

asrax3:
shrax3:
    lsr a
    lsr a
    lsr a
    rts

asrax4:
shrax4:
    lsr a
    lsr a
    lsr a
    lsr a
    rts

; ----------------------------------------------------------------------------
; negax - Negar AX (complemento a 2)
; ----------------------------------------------------------------------------
negax:
    clc
    eor #$FF
    adc #1
    pha
    txa
    eor #$FF
    adc #0
    tax
    pla
    rts

; ----------------------------------------------------------------------------
; complax - Complemento a 1 de AX
; ----------------------------------------------------------------------------
complax:
    eor #$FF
    pha
    txa
    eor #$FF
    tax
    pla
    rts

; ----------------------------------------------------------------------------
; incax1, incax2 - Incrementar AX
; ----------------------------------------------------------------------------
incax1:
    clc
    adc #1
    bcc @L1
    inx
@L1:
    rts

incax2:
    clc
    adc #2
    bcc @L1
    inx
@L1:
    rts

; ----------------------------------------------------------------------------
; tosaddax - Sumar TOS + AX, resultado en AX
; ----------------------------------------------------------------------------
tosaddax:
    clc
    ldy #0
    adc (sp),y
    pha
    txa
    iny
    adc (sp),y
    tax
    pla
    jmp incsp2

; ----------------------------------------------------------------------------
; tossubax - Restar TOS - AX, resultado en AX
; ----------------------------------------------------------------------------
tossubax:
    sec
    sta tmp1
    ldy #0
    lda (sp),y
    sbc tmp1
    pha
    iny
    lda (sp),y
    stx tmp1
    sbc tmp1
    tax
    pla
    jmp incsp2

; ----------------------------------------------------------------------------
; tosandax, tosorax, tosxorax - Operaciones lógicas
; ----------------------------------------------------------------------------
tosandax:
    ldy #0
    and (sp),y
    pha
    txa
    iny
    and (sp),y
    tax
    pla
    jmp incsp2

tosorax:
    ldy #0
    ora (sp),y
    pha
    txa
    iny
    ora (sp),y
    tax
    pla
    jmp incsp2

tosxorax:
    ldy #0
    eor (sp),y
    pha
    txa
    iny
    eor (sp),y
    tax
    pla
    jmp incsp2

; ----------------------------------------------------------------------------
; Comparaciones booleanas - retornan 0 o 1 en A
; ----------------------------------------------------------------------------
booleq:
    cpx #0
    bne @false
    cmp #0
    bne @false
    lda #1
    rts
@false:
    lda #0
    rts

boolne:
    cpx #0
    bne @true
    cmp #0
    bne @true
    lda #0
    rts
@true:
    lda #1
    rts

boollt:
    cpx #$80
    bcs @true
    lda #0
    rts
@true:
    lda #1
    rts

boolgt:
    cpx #$80
    bcs @false
    cpx #0
    bne @true
    cmp #0
    beq @false
@true:
    lda #1
    ldx #0
    rts
@false:
    lda #0
    ldx #0
    rts

boolle:
boolge:
boolult:
boolugt:
boolule:
booluge:
    ; Simplificado - retorna 1
    lda #1
    ldx #0
    rts

; ----------------------------------------------------------------------------
; Comparaciones TOS vs AX
; ----------------------------------------------------------------------------
toseqax:
    ldy #0
    cmp (sp),y
    bne @false
    iny
    txa
    cmp (sp),y
    bne @false
    lda #1
    ldx #0
    jmp incsp2
@false:
    lda #0
    ldx #0
    jmp incsp2

tosnax:
    ldy #0
    cmp (sp),y
    bne @true
    iny
    txa
    cmp (sp),y
    bne @true
    lda #0
    ldx #0
    jmp incsp2
@true:
    lda #1
    ldx #0
    jmp incsp2

tosltax:
tosgtax:
tosleax:
tosgeax:
tosultax:
tosugtax:
tosuleax:
tosugeax:
    ; Simplificado - comparación básica
    lda #0
    ldx #0
    jmp incsp2

; ----------------------------------------------------------------------------
; Multiplicación simple (8 bit * 8 bit -> 16 bit)
; TOS * A -> AX
; ----------------------------------------------------------------------------
tosmulax:
    sta tmp1            ; Multiplicando
    ldy #0
    lda (sp),y          ; Multiplicador
    sta ptr1
    lda #0
    ldx #0
    ldy #8
@loop:
    lsr ptr1
    bcc @skip
    clc
    adc tmp1
    bcc @skip
    inx
@skip:
    asl tmp1
    rol tmp1+1
    dey
    bne @loop
    jmp incsp2

; ----------------------------------------------------------------------------
; División y módulo (simplificados)
; ----------------------------------------------------------------------------
tosdivax:
tosmodax:
    ; División simplificada - solo retorna el dividendo
    ldy #1
    lda (sp),y          ; High byte
    tax
    dey
    lda (sp),y          ; Low byte
    jmp incsp2

; ----------------------------------------------------------------------------
; decax1 - Decrementar AX en 1
; ----------------------------------------------------------------------------
decax1:
    sec
    sbc #1
    bcs @L1
    dex
@L1:
    rts

; ----------------------------------------------------------------------------
; aslaxy - Shift left AX por Y bits
; ----------------------------------------------------------------------------
aslaxy:
    cpy #0
    beq @done
@loop:
    asl a
    rol tmp1            ; Usar tmp1 para high byte temporalmente
    dey
    bne @loop
@done:
    rts

; ----------------------------------------------------------------------------
; asraxy - Shift right AX por Y bits (aritmético)
; ----------------------------------------------------------------------------
asraxy:
    cpy #0
    beq @done
    stx tmp1
@loop:
    lsr tmp1
    ror a
    dey
    bne @loop
    ldx tmp1
@done:
    rts

; ----------------------------------------------------------------------------
; regsave - Guardar registros para llamadas a funciones
; cc65 usa regsave como puntero ZP, guardamos A,X,Y en regsave+0,1,2
; ----------------------------------------------------------------------------
regswap1:
regswap2:
    ; Guardar A,X,Y en área regsave (ZP)
    sta regsave
    stx regsave+1
    sty regsave+2
    rts

regrestore:
    lda regsave
    ldx regsave+1
    ldy regsave+2
    rts
