; ============================================
; simple_vectors.s - Vectores de interrupción 6502
; ============================================
; Define los vectores NMI, RESET e IRQ
; El vector RESET apunta al startup (_init)
; ============================================

.import _init        ; Punto de entrada del startup

.segment "CODE"

; Manejadores de interrupción (vacíos por defecto)
nmi_handler:
    rti

irq_handler:
    rti

.segment "VECTORS"

; Tabla de vectores del 6502 ($BFFA-$BFFF)
.addr   nmi_handler  ; $BFFA: NMI
.addr   _init        ; $BFFC: RESET -> startup
.addr   irq_handler  ; $BFFE: IRQ
