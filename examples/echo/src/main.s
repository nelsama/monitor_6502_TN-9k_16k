; ============================================
; CALABOZO - Juego de Aventura (SIN TXS)
; ============================================

.setcpu "6502"

; Hardware Definitions
UART_DATA    = $C020
UART_STATUS  = $C021
LEDS         = $C001

; Variables ZP
room        = $20
key         = $21
sword       = $22
dooropen    = $23
dragondead  = $24
char        = $25

.segment "STARTUP"

start:
    sei             ; Disable interrupts
    cld             ; Clear decimal mode
    
    ; Init Variables (SIN TXS!)
    lda #0
    sta room
    sta key
    sta sword
    sta dooropen
    sta dragondead
    
    ; Intro
    jsr p_intro
    
main_loop:
    jsr show_room
    
    ; Prompt
    lda #'>'
    jsr putc
    lda #' '
    jsr putc
    
    ; Read Command
    jsr getc
    sta char
    jsr putc
    jsr crlf
    
    ; Uppercase
    lda char
    cmp #'a'
    bcc check_cmd
    cmp #'z'+1
    bcs check_cmd
    sec
    sbc #32
    sta char

check_cmd:
    lda char
    cmp #'N'
    bne not_n
    jmp cmd_norte
not_n:
    cmp #'S'
    bne not_s
    jmp cmd_sur
not_s:
    cmp #'E'
    bne not_e
    jmp cmd_este
not_e:
    cmp #'O'
    bne not_o
    jmp cmd_oeste
not_o:
    cmp #'W'
    bne not_w
    jmp cmd_oeste
not_w:
    cmp #'C'
    bne not_c
    jmp cmd_coger
not_c:
    cmp #'U'
    bne not_u
    jmp cmd_usar
not_u:
    cmp #'I'
    bne not_i
    jmp cmd_inv
not_i:
    cmp #'H'
    bne not_h
    jmp cmd_help
not_h:
    jsr p_huh
    jmp main_loop

; Game Logic
show_room:
    lda room
    cmp #0
    bne sr1
    jsr p_r0
    lda key
    bne sr_d
    jsr p_keyhere
    jmp sr_d
sr1:
    cmp #1
    bne sr2
    jsr p_r1
    jmp sr_d
sr2:
    cmp #2
    bne sr3
    jsr p_r2
    lda sword
    bne sr_d
    jsr p_swordhere
    jmp sr_d
sr3:
    cmp #3
    bne sr4
    jsr p_r3
    jmp sr_d
sr4:
    cmp #4
    bne sr5
    jsr p_r4
    jmp sr_d
sr5:
    jsr p_r5
sr_d:
    rts

cmd_norte:
    lda room
    cmp #3
    bne norte_fail
    lda dooropen
    bne norte_ok
    jsr p_locked
    jmp main_loop
norte_ok:
    lda #4
    sta room
    jmp main_loop
norte_fail:
    jsr p_noway
    jmp main_loop

cmd_sur:
    lda room
    cmp #0
    bne sur1
    lda #1
    sta room
    jmp main_loop
sur1:
    cmp #3
    bne sur2
    lda #1
    sta room
    jmp main_loop
sur2:
    cmp #4
    bne sur_fail
    lda dragondead
    bne sur_win
    jsr p_blocked
    jmp main_loop
sur_win:
    lda #5
    sta room
    jsr p_r5
    jmp victory
sur_fail:
    jsr p_noway
    jmp main_loop

cmd_este:
    lda room
    cmp #1
    bne este_fail
    lda #2
    sta room
    jmp main_loop
este_fail:
    jsr p_noway
    jmp main_loop

cmd_oeste:
    lda room
    cmp #1
    bne oeste1
    lda #3
    sta room
    jmp main_loop
oeste1:
    cmp #2
    bne oeste_fail
    lda #1
    sta room
    jmp main_loop
oeste_fail:
    jsr p_noway
    jmp main_loop

cmd_coger:
    lda room
    cmp #0
    bne coger1
    lda key
    bne coger_nada
    lda #1
    sta key
    jsr p_gotkey
    jmp main_loop
coger1:
    cmp #2
    bne coger_nada
    lda sword
    bne coger_nada
    lda #1
    sta sword
    jsr p_gotsword
    jmp main_loop
coger_nada:
    jsr p_nothing
    jmp main_loop

cmd_usar:
    lda room
    cmp #3
    bne usar1
    lda key
    beq usar_cant
    lda dooropen
    bne usar_already
    lda #1
    sta dooropen
    jsr p_opened
    jmp main_loop
usar_already:
    jsr p_already
    jmp main_loop
usar1:
    cmp #4
    bne usar_cant
    lda sword
    beq usar_cant
    lda dragondead
    bne usar_cant
    lda #1
    sta dragondead
    jsr p_killed
    jmp main_loop
usar_cant:
    jsr p_cant
    jmp main_loop

cmd_inv:
    jsr p_carry
    lda key
    beq inv_nk
    jsr p_ikey
inv_nk:
    lda sword
    beq inv_ns
    jsr p_isword
inv_ns:
    lda key
    ora sword
    bne inv_d
    jsr p_empty
inv_d:
    jsr crlf
    jmp main_loop

cmd_help:
    jsr p_help
    jmp main_loop

victory:
    jsr p_win
vloop:
    lda #$00
    sta LEDS
    jsr delay
    lda #$FF
    sta LEDS
    jsr delay
    jmp vloop

; UART Drivers
putc:
    pha
@wait_tx:
    lda UART_STATUS
    and #$01
    beq @wait_tx
    pla
    sta UART_DATA
    rts

getc:
@wait_rx:
    lda UART_STATUS
    and #$02
    beq @wait_rx
    lda UART_DATA
    rts

crlf:
    lda #13
    jsr putc
    lda #10
    jsr putc
    rts
    
delay:
    ldx #$20
@o: ldy #$00
@i: dey
    bne @i
    dex
    bne @o
    rts

; Strings
p_intro:
    jsr crlf
    ldx #0
@l: lda s_title,x
    beq @d
    jsr putc
    inx
    jmp @l
@d: rts

s_title: .byte "=== CALABOZO ===", 13, 10, "Escapa! H=ayuda", 13, 10, 0

p_huh:
    lda #'?'
    jsr putc
    jmp crlf

p_noway:
    lda #'N'
    jsr putc
    lda #'o'
    jsr putc
    jsr crlf
    rts

p_locked:
    lda #'C'
    jsr putc
    lda #'e'
    jsr putc
    lda #'r'
    jsr putc
    lda #'r'
    jsr putc
    lda #'a'
    jsr putc
    lda #'d'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_blocked:
    lda #'D'
    jsr putc
    lda #'r'
    jsr putc
    lda #'a'
    jsr putc
    lda #'g'
    jsr putc
    lda #'o'
    jsr putc
    lda #'n'
    jsr putc
    jmp crlf

p_nothing:
    lda #'N'
    jsr putc
    lda #'a'
    jsr putc
    lda #'d'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_gotkey:
    lda #'L'
    jsr putc
    lda #'l'
    jsr putc
    lda #'a'
    jsr putc
    lda #'v'
    jsr putc
    lda #'e'
    jsr putc
    jmp crlf

p_gotsword:
    lda #'E'
    jsr putc
    lda #'s'
    jsr putc
    lda #'p'
    jsr putc
    lda #'a'
    jsr putc
    lda #'d'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_opened:
    lda #'A'
    jsr putc
    lda #'b'
    jsr putc
    lda #'i'
    jsr putc
    lda #'e'
    jsr putc
    lda #'r'
    jsr putc
    lda #'t'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_already:
    lda #'Y'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_killed:
    lda #'M'
    jsr putc
    lda #'u'
    jsr putc
    lda #'e'
    jsr putc
    lda #'r'
    jsr putc
    lda #'t'
    jsr putc
    lda #'o'
    jsr putc
    jmp crlf

p_cant:
    lda #'N'
    jsr putc
    lda #'o'
    jsr putc
    jmp crlf

p_carry:
    lda #'['
    jsr putc
    rts

p_ikey:
    lda #'L'
    jsr putc
    rts

p_isword:
    lda #'E'
    jsr putc
    rts

p_empty:
    lda #'-'
    jsr putc
    rts

p_help:
    jsr crlf
    lda #'N'
    jsr putc
    lda #'S'
    jsr putc
    lda #'E'
    jsr putc
    lda #'O'
    jsr putc
    jsr crlf
    lda #'C'
    jsr putc
    lda #'='
    jsr putc
    lda #'C'
    jsr putc
    lda #'o'
    jsr putc
    lda #'g'
    jsr putc
    lda #'e'
    jsr putc
    jsr crlf
    lda #'U'
    jsr putc
    lda #'='
    jsr putc
    lda #'U'
    jsr putc
    lda #'s'
    jsr putc
    lda #'a'
    jsr putc
    jmp crlf

p_win:
    jsr crlf
    lda #'V'
    jsr putc
    lda #'I'
    jsr putc
    lda #'C'
    jsr putc
    lda #'T'
    jsr putc
    lda #'O'
    jsr putc
    lda #'R'
    jsr putc
    lda #'I'
    jsr putc
    lda #'A'
    jsr putc
    jmp crlf

p_keyhere:
    lda #'L'
    jsr putc
    lda #'L'
    jsr putc
    lda #'A'
    jsr putc
    lda #'V'
    jsr putc
    lda #'E'
    jsr putc
    jmp crlf

p_swordhere:
    lda #'E'
    jsr putc
    lda #'S'
    jsr putc
    lda #'P'
    jsr putc
    lda #'A'
    jsr putc
    lda #'D'
    jsr putc
    lda #'A'
    jsr putc
    jmp crlf

p_r0:
    jsr crlf
    lda #'['
    jsr putc
    lda #'C'
    jsr putc
    lda #'E'
    jsr putc
    lda #'L'
    jsr putc
    lda #'D'
    jsr putc
    lda #'A'
    jsr putc
    lda #']'
    jsr putc
    jsr crlf
    lda #'S'
    jsr putc
    lda #'a'
    jsr putc
    lda #'l'
    jsr putc
    lda #':'
    jsr putc
    lda #'S'
    jsr putc
    jmp crlf

p_r1:
    jsr crlf
    lda #'['
    jsr putc
    lda #'P'
    jsr putc
    lda #'A'
    jsr putc
    lda #'S'
    jsr putc
    lda #'I'
    jsr putc
    lda #'L'
    jsr putc
    lda #'L'
    jsr putc
    lda #'O'
    jsr putc
    lda #']'
    jsr putc
    jsr crlf
    lda #'S'
    jsr putc
    lda #'a'
    jsr putc
    lda #'l'
    jsr putc
    lda #':'
    jsr putc
    lda #'N'
    jsr putc
    lda #' '
    jsr putc
    lda #'E'
    jsr putc
    lda #' '
    jsr putc
    lda #'O'
    jsr putc
    jmp crlf

p_r2:
    jsr crlf
    lda #'['
    jsr putc
    lda #'A'
    jsr putc
    lda #'R'
    jsr putc
    lda #'M'
    jsr putc
    lda #'E'
    jsr putc
    lda #'R'
    jsr putc
    lda #'I'
    jsr putc
    lda #'A'
    jsr putc
    lda #']'
    jsr putc
    jsr crlf
    lda #'S'
    jsr putc
    lda #'a'
    jsr putc
    lda #'l'
    jsr putc
    lda #':'
    jsr putc
    lda #'O'
    jsr putc
    jmp crlf

p_r3:
    jsr crlf
    lda #'['
    jsr putc
    lda #'D'
    jsr putc
    lda #'R'
    jsr putc
    lda #'A'
    jsr putc
    lda #'G'
    jsr putc
    lda #'O'
    jsr putc
    lda #'N'
    jsr putc
    lda #']'
    jsr putc
    jsr crlf
    lda #'S'
    jsr putc
    lda #'a'
    jsr putc
    lda #'l'
    jsr putc
    lda #':'
    jsr putc
    lda #'N'
    jsr putc
    lda #' '
    jsr putc
    lda #'E'
    jsr putc
    jmp crlf

p_r4:
    jsr crlf
    lda #'['
    jsr putc
    lda #'T'
    jsr putc
    lda #'E'
    jsr putc
    lda #'S'
    jsr putc
    lda #'O'
    jsr putc
    lda #'R'
    jsr putc
    lda #'O'
    jsr putc
    lda #']'
    jsr putc
    jsr crlf
    lda #'S'
    jsr putc
    lda #'a'
    jsr putc
    lda #'l'
    jsr putc
    lda #':'
    jsr putc
    lda #'S'
    jsr putc
    jmp crlf

p_r5:
    jsr crlf
    lda #'['
    jsr putc
    lda #'S'
    jsr putc
    lda #'A'
    jsr putc
    lda #'L'
    jsr putc
    lda #'I'
    jsr putc
    lda #'D'
    jsr putc
    lda #'A'
    jsr putc
    lda #']'
    jsr putc
    jmp crlf
