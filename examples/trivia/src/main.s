; ============================================
; Trivia Game
; - Preguntas y Respuestas via UART
; - Puntaje en LEDs (Binario invertido)
; ============================================

.setcpu "6502"

; Hardware Definitions
UART_DATA    = $C020
UART_STATUS  = $C021
LEDS         = $C001

; Variables en Zero Page
score        = $20
temp         = $21
ptr_l        = $22
ptr_h        = $23

.segment "STARTUP"

start:
    sei             ; Disable interrupts (CRITICAL)
    cld             ; Clear decimal mode
    
    ; Init Score
    lda #0
    sta score
    lda #$FF        ; LEDs OFF
    sta LEDS
    
    ; Print Title
    ldx #0
    jsr print_str_ix
    
    ; Question 1
    ldx #1          ; Index for Q1 string
    jsr print_str_ix
    lda #'C'        ; Correct Answer
    jsr ask_question
    
    ; Question 2
    ldx #2
    jsr print_str_ix
    lda #'A'
    jsr ask_question
    
    ; Question 3
    ldx #3
    jsr print_str_ix
    lda #'B'
    jsr ask_question

    ; Game Over
    ldx #4
    jsr print_str_ix
    
    ; Volver al monitor
    rts

; --------------------------------------
; ask_question: Espera respuesta y valida
; Entrada: A = Respuesta Correcta
; --------------------------------------
ask_question:
    sta temp        ; Guardar respuesta correcta
    
    ; Esperar input
    jsr getc
    pha             ; Guardar input original
    
    ; Echo input
    jsr putc
    jsr crlf
    
    pla             ; Recuperar input
    
    ; Convertir a Mayuscula si es a-z
    cmp #'a'
    bcc @check
    cmp #'z'+1
    bcs @check
    sec
    sbc #32         ; 'a' -> 'A'
@check:
    cmp temp        ; Comparar con correcta
    beq correct
    
    ; Incorrecto
    ldx #6          ; "Incorrecto"
    jsr print_str_ix
    rts
    
correct:
    ldx #5          ; "Correcto"
    jsr print_str_ix
    
    ; Sumar punto
    inc score
    
    ; Actualizar LEDs (Score en binario, logica negativa)
    lda score
    eor #$FF        ; Invertir bits
    sta LEDS
    rts

; --------------------------------------
; print_str_ix: Imprime string de tabla
; Entrada: X = Indice (0-based)
; --------------------------------------
print_str_ix:
    ; Configurar puntero a tabla
    lda table_lo,x
    sta ptr_l
    lda table_hi,x
    sta ptr_h
    
    ldy #0
@loop:
    lda (ptr_l),y
    beq @done
    jsr putc
    iny
    jmp @loop
@done:
    rts

; --------------------------------------
; Driver UART (Polling seguro)
; --------------------------------------
putc:
    pha
@wait_tx:
    lda UART_STATUS
    and #$01        ; TX Ready?
    beq @wait_tx
    pla
    sta UART_DATA
    rts

getc:
@wait_rx:
    lda UART_STATUS
    and #$02        ; RX Ready?
    beq @wait_rx
    lda UART_DATA
    rts

crlf:
    lda #13
    jsr putc
    lda #10
    jsr putc
    rts

; --------------------------------------
; Datos (Strings)
; --------------------------------------
; Nota: CA65 no interpreta \r\n, hay que usar bytes 13, 10
s_title: .byte "--- TRIVIA 6502 ---", 13, 10, 13, 10, 0
s_q1:    .byte "1. CPU del Apple II? (A:Z80 B:8086 C:6502): ", 0
s_q2:    .byte "2. Bytes en 1KB? (A:1024 B:1000 C:8): ", 0
s_q3:    .byte "3. Hex de 15? (A:E B:F C:A): ", 0
s_end:   .byte 13, 10, "--- FIN DEL JUEGO ---", 13, 10, 0
s_cor:   .byte " -> CORRECTO!", 13, 10, 0
s_inc:   .byte " -> MAL!", 13, 10, 0

; Tabla de punteros (Low/High bytes)
table_lo:
    .byte <s_title, <s_q1, <s_q2, <s_q3, <s_end, <s_cor, <s_inc
table_hi:
    .byte >s_title, >s_q1, >s_q2, >s_q3, >s_end, >s_cor, >s_inc
