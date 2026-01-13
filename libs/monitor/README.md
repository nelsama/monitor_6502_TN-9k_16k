# Monitor 6502 v2.3.0 + SD Card

Monitor/debugger interactivo para el procesador 6502 a través de UART para Tang Nano 9K con soporte de SD Card.

## Características

- ✅ Lectura/escritura de memoria
- ✅ Dump de memoria en formato hex+ASCII
- ✅ Carga de programas en hexadecimal interactivo
- ✅ Ejecución de código en cualquier dirección
- ✅ Desensamblador completo 6502
- ✅ Fill de memoria
- ✅ Info de memoria (comando I)
- ✅ **SD Card**: guardar, cargar, listar, eliminar archivos
- ✅ **XMODEM**: transferencia de archivos desde PC
- ✅ Ayuda contextual por comando (`H cmd`)

## Mapa de Memoria

| Rango | Tamaño | Descripción |
|-------|--------|-------------|
| `$0000-$00FF` | 256 bytes | Zero Page |
| `$0100-$01FF` | 256 bytes | Stack del 6502 |
| `$0200-$07FF` | 1.5 KB | BSS (variables del monitor) |
| `$0800-$3DFF` | ~14 KB | **RAM usuario** (para tus programas) |
| `$3E00-$3FFF` | 512 bytes | Stack de CC65 |
| `$C000-$C0FF` | 256 bytes | Puertos I/O |
| `$8000-$BFFF` | 16 KB | ROM (este monitor) |

## Formato de Parámetros

**Todo en HEXADECIMAL** (sin prefijo `$` ni `0x`):
- `addr` = dirección de 4 dígitos (ej: `0800`, `C001`, `8000`)
- `len` = longitud en bytes (ej: `10`=16, `100`=256, `1000`=4096)
- `val` = valor de 1 byte (ej: `FF`, `A9`, `00`)

---

## Comandos Básicos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **R** | `R [addr]` | Ejecutar programa (default: $0800) |
| **RD** | `RD addr` | Leer byte de memoria |
| **W** | `W addr val` | Escribir byte en memoria |
| **D** | `D addr [len]` | Dump de memoria hex + ASCII (default: 64 bytes) |
| **L** | `L addr` | Modo carga de bytes hex interactivo |
| **F** | `F addr len val` | Llenar memoria con valor |
| **M** | `M addr [n]` | Desensamblar n instrucciones (default: 16) |

## Comandos de Análisis de Memoria

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **I** | `I` | Info del sistema (mapa de memoria) |

## Comandos SD Card

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **SD** | `SD` | Inicializar SD Card |
| **LS** | `LS` | Listar archivos |
| **SAVE** | `SAVE file addr len` | Guardar memoria a archivo |
| **LOAD** | `LOAD file addr` | Cargar archivo a memoria |
| **DEL** | `DEL file` | Eliminar archivo |
| **CAT** | `CAT file` | Ver contenido en hex |

## Otros Comandos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **H** | `H` | Ayuda general |
| **H** | `H cmd` | Ayuda detallada del comando |
| **Q** | `Q` | Salir del monitor |

---

## Ejemplos de Uso

### Leer memoria
```
>RD 0800
$0800 = $A9

>RD C001
$C001 = $3F
```

### Escribir memoria
```
>W 0800 EA
$0800 <- $EA

>W C001 3F
$C001 <- $3F    (enciende LEDs)
```

### Dump de memoria
```
>D 8000 40
8000: A9 00 8D 01 C0 A9 C0 8D  03 C0 20 00 90 A2 FF CA  |..........  ....|
8010: D0 FD 8A 8D 01 C0 4C 06  80 00 00 00 00 00 00 00  |......L.........|
```

### Cargar programa manualmente
```
>L 0800
Modo carga en $0800 (terminar con '.')
:A9 3F 8D 01 C0 60 .
Cargados 0006 bytes
```

### Ejecutar código
```
>R 0800
Ejecutando en $0800...
Retorno de $0800
```

### Desensamblar
```
>M 0800
0800  A9 3F     LDA #$3F
0202  8D 01 C0  STA $C001
0205  60        RTS
```

### Llenar memoria
```
>F 0300 100 EA
Filled $0300-$03FF con $EA
```

### Ayuda de un comando específico
```
>H L
L addr - Cargar hex interactivo
Escribe bytes, '.' termina
Ej: L 0800 -> A9 01 8D 01 C0 60 .
```

---

## SD Card - Ejemplos

### Inicializar y listar
```
>SD
SD Card inicializada
Tipo: SDHC
Capacidad: 32 GB

>LS
PROG.BIN     256
DATA.DAT    1024
TEST.BIN     128
3 archivos
```

### Guardar programa a SD
```
>SAVE MIPROG.BIN 0800 100
Guardando MIPROG.BIN...
256 bytes guardados
```

### Cargar programa desde SD
```
>LOAD MIPROG.BIN 0800
Cargando MIPROG.BIN en $0800...
256 bytes cargados

>R 0800
```

---

# Creación de Programas para el Monitor

Puedes crear programas en **Ensamblador** o **C**, compilarlos, y cargarlos al monitor vía SD Card o manualmente.

## Opción 1: Programa en Ensamblador (ASM)

### Paso 1: Crear el código fuente

Crea un archivo `miprog.s`:

```asm
; miprog.s - Programa para cargar en $0800
; Ejemplo: Parpadeo de LEDs

.segment "CODE"

LEDS = $C001        ; Puerto de LEDs

start:
    lda #$3F        ; Encender todos los LEDs
    sta LEDS
    
    jsr delay       ; Esperar
    
    lda #$00        ; Apagar LEDs
    sta LEDS
    
    jsr delay       ; Esperar
    
    jmp start       ; Repetir (o RTS para volver al monitor)

; Rutina de delay
delay:
    ldx #$FF
@loop1:
    ldy #$FF
@loop2:
    dey
    bne @loop2
    dex
    bne @loop1
    rts
```

### Paso 2: Crear archivo de configuración

Crea `programa.cfg`:

```
MEMORY {
    RAM: start = $0800, size = $3C00, file = %O;
}
SEGMENTS {
    CODE: load = RAM, type = rw;
    RODATA: load = RAM, type = ro;
    DATA: load = RAM, type = rw;
    BSS: load = RAM, type = bss;
}
```

### Paso 3: Compilar

```powershell
# Ensamblar
ca65 -t none -o miprog.o miprog.s

# Linkear a binario desde $0800
ld65 -C programa.cfg -o MIPROG.BIN miprog.o
```

### Paso 4: Cargar y ejecutar

1. Copia `MIPROG.BIN` a la SD Card
2. En el monitor:
```
>SD
>LOAD MIPROG.BIN 0800
>R 0800
```

---

## Opción 2: Programa en C

### Paso 1: Crear el código fuente

Crea un archivo `miprog.c`:

```c
/* miprog.c - Programa para cargar en $0800 */

/* Puerto de LEDs */
#define LEDS (*(volatile unsigned char*)0xC001)

/* Función de delay */
void delay(void) {
    unsigned int i;
    for (i = 0; i < 30000; i++) {
        /* Espera */
    }
}

/* Punto de entrada - DEBE llamarse main */
void main(void) {
    unsigned char patron = 0x01;
    
    /* LED corriendo de izquierda a derecha */
    while (1) {
        LEDS = patron;
        delay();
        
        patron <<= 1;   /* Rotar izquierda */
        if (patron == 0x40) {
            patron = 0x01;  /* Volver al inicio */
        }
    }
    
    /* Si quieres que regrese al monitor: */
    /* return; */
}
```

### Paso 2: Crear startup mínimo

Crea `crt0.s` (código de inicio):

```asm
; crt0.s - Startup mínimo para programas standalone

.export _init
.export __STARTUP__ : absolute = 1

.import _main
.importzp sp

.segment "STARTUP"

_init:
    ; Inicializar stack de CC65
    lda #<$3DFF
    sta sp
    lda #>$3DFF
    sta sp+1
    
    ; Llamar a main
    jsr _main
    
    ; Si main retorna, RTS al monitor
    rts
```

### Paso 3: Compilar

```powershell
# Compilar C a ensamblador
cc65 -t none -O --cpu 6502 -o miprog.s miprog.c

# Ensamblar todo
ca65 -t none -o miprog.o miprog.s
ca65 -t none -o crt0.o crt0.s

# Linkear (crt0 primero para que _init esté en $0800)
ld65 -C programa.cfg -o MIPROG.BIN crt0.o miprog.o
```

### Paso 4: Cargar y ejecutar

```
>SD
>LOAD MIPROG.BIN 0800
>D 0800 20          ; Verificar que cargó
>R 0800             ; Ejecutar
```

---

## Opción 3: Carga Manual (sin SD)

Para programas pequeños, puedes introducir los bytes directamente:

```
>L 0800
:A9 3F 8D 01 C0 60 .
Cargados 0006 bytes

>M 0800 3
0800  A9 3F     LDA #$3F
0202  8D 01 C0  STA $C001
0205  60        RTS

>R 0800
```

Este programa:
- `A9 3F` = LDA #$3F (cargar patrón)
- `8D 01 C0` = STA $C001 (escribir a LEDs)
- `60` = RTS (volver al monitor)

---

## Programas de Ejemplo

### Ejemplo 1: Contador binario en LEDs (ASM)

```asm
; contador.s
.segment "CODE"

LEDS = $C001

start:
    ldx #$00
loop:
    txa
    sta LEDS        ; Mostrar contador
    
    ; Delay
    ldy #$00
delay:
    nop
    nop
    dey
    bne delay
    
    inx             ; Incrementar
    jmp loop
```

### Ejemplo 2: Echo UART (C)

```c
/* echo.c - Lee UART y reenvía */
#define UART_DATA    (*(volatile unsigned char*)0xC020)
#define UART_STATUS  (*(volatile unsigned char*)0xC021)
#define UART_RX_VALID 0x02
#define UART_TX_READY 0x01

void main(void) {
    char c;
    
    while (1) {
        /* Esperar dato */
        while (!(UART_STATUS & UART_RX_VALID));
        c = UART_DATA;
        
        /* Esperar TX listo */
        while (!(UART_STATUS & UART_TX_READY));
        UART_DATA = c;
        
        /* Salir con ESC */
        if (c == 0x1B) return;
    }
}
```

### Ejemplo 3: Patrón Knight Rider (ASM)

```asm
; knight.s - LED tipo Knight Rider
.segment "CODE"

LEDS = $C001

start:
    ldx #$00        ; Dirección: 0=derecha, 1=izquierda
    lda #$01        ; Patrón inicial

loop:
    sta LEDS
    jsr delay
    
    cpx #$00
    beq go_left
    
go_right:
    lsr a           ; Rotar derecha
    cmp #$01
    bne loop
    ldx #$00        ; Cambiar dirección
    beq loop
    
go_left:
    asl a           ; Rotar izquierda
    cmp #$20        ; Llegó al bit 5?
    bne loop
    ldx #$01        ; Cambiar dirección
    bne loop

delay:
    pha
    tya
    pha
    ldy #$00
@d1:
    nop
    dey
    bne @d1
    pla
    tay
    pla
    rts
```

---

## Script de Compilación

Crea un archivo `compile.bat` para automatizar:

```batch
@echo off
REM compile.bat - Compila programa para Monitor 6502
REM Uso: compile.bat nombre (sin extensión)

if "%1"=="" (
    echo Uso: compile.bat nombre
    exit /b 1
)

set NAME=%1
set CC65_PATH=D:\cc65\bin

echo Compilando %NAME%...

REM Si es .c
if exist %NAME%.c (
    %CC65_PATH%\cc65 -t none -O --cpu 6502 -o %NAME%.s %NAME%.c
    %CC65_PATH%\ca65 -t none -o %NAME%.o %NAME%.s
    if exist crt0.o (
        %CC65_PATH%\ld65 -C programa.cfg -o %NAME%.BIN crt0.o %NAME%.o
    ) else (
        %CC65_PATH%\ld65 -C programa.cfg -o %NAME%.BIN %NAME%.o
    )
    goto done
)

REM Si es .s
if exist %NAME%.s (
    %CC65_PATH%\ca65 -t none -o %NAME%.o %NAME%.s
    %CC65_PATH%\ld65 -C programa.cfg -o %NAME%.BIN %NAME%.o
    goto done
)

echo Error: No se encontró %NAME%.c ni %NAME%.s
exit /b 1

:done
echo.
echo Generado: %NAME%.BIN
echo.
echo Para usar:
echo   1. Copia %NAME%.BIN a la SD Card
echo   2. En el monitor:
echo      ^>SD
echo      ^>LOAD %NAME%.BIN 0800
echo      ^>R 0800
```

---

## Notas Técnicas

- **Buffer de entrada**: 64 caracteres máximo por línea
- **RAM usable**: `$0800-$3DFF` (~15KB para tus programas)
- **Retorno al monitor**: Tu código debe terminar con `RTS` ($60)
- **SD Card**: Formato nombres 8.3 mayúsculas (ej: `PROG.BIN`)
- **Velocidad**: CPU 6502 @ 3.375 MHz

## Hardware Soportado

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| LEDs | `$C001` | 6 LEDs (bits 0-5) |
| LED Config | `$C003` | Configuración E/S |
| UART Data | `$C020` | Datos TX/RX |
| UART Status | `$C021` | Estado UART |
| SPI Data | `$C010` | Datos SPI |
| SPI Status | `$C011` | Estado SPI |
| SPI CS | `$C012` | Chip Select |

## Licencia

MIT
