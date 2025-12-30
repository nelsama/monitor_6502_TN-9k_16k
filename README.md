# Monitor 6502 v2.0 + SD Card - Tang Nano 9K

🚀 **Monitor/Debugger interactivo** para CPU 6502 sobre FPGA Tang Nano 9K via UART con soporte de **SD Card**.

Permite programar, depurar y ejecutar código en tiempo real a través de una interfaz de comandos estilo Wozmon.

## Características

- ✅ CPU 6502 @ 3.375 MHz en FPGA Tang Nano 9K
- ✅ Monitor interactivo via UART (115200 baud)
- ✅ Lectura/escritura de memoria
- ✅ Carga de programas en hexadecimal
- ✅ Ejecución de código en cualquier dirección
- ✅ Desensamblador completo 6502
- ✅ Análisis de memoria RAM (scan, test, mapa visual)
- ✅ **SD Card**: guardar, cargar, listar, eliminar archivos
- ✅ **Ayuda contextual** por comando (`H cmd`)
- ✅ Control de 6 LEDs
- ✅ ROM de 16KB
- ✅ Compilación con cc65

---

## Comandos del Monitor

Todo en **HEXADECIMAL** (sin prefijo `$` ni `0x`)

### Comandos Básicos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **R** | `R addr` | Leer byte de memoria |
| **W** | `W addr val` | Escribir byte en memoria |
| **D** | `D addr [len]` | Dump memoria hex+ASCII (default: 64 bytes) |
| **L** | `L addr` | Cargar bytes hex interactivo (terminar con `.`) |
| **G** | `G addr` | Ejecutar código (GO/RUN) |
| **F** | `F addr len val` | Llenar memoria con valor |
| **M** | `M addr [n]` | Desensamblar n instrucciones (default: 16) |

### Comandos de Análisis de Memoria

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **I** | `I` | Info del sistema (mapa de memoria) |
| **S** | `S addr len` | Escanear memoria libre ($00 o $FF) |
| **T** | `T addr len` | Test de RAM (¡destruye datos!) |
| **V** | `V` | Mapa visual de uso de RAM |

### Comandos SD Card

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **SD** | `SD` | Inicializar SD Card |
| **LS** | `LS` | Listar archivos |
| **SAVE** | `SAVE file addr len` | Guardar memoria a archivo |
| **LOAD** | `LOAD file addr` | Cargar archivo a memoria |
| **DEL** | `DEL file` | Eliminar archivo |
| **CAT** | `CAT file` | Ver contenido del archivo en hex |

### Comandos de Ayuda

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **H** | `H` | Ayuda general (lista de comandos) |
| **H** | `H cmd` | Ayuda detallada del comando específico |
| **?** | `?` | Igual que H |
| **Q** | `Q` | Salir/reiniciar monitor |

**Ejemplos de ayuda:**
- `H L` → Ayuda del comando Load
- `H SAVE` → Ayuda del comando Save
- `H D` → Ayuda del comando Dump

---

## Ejemplos de Uso

### Operaciones básicas de memoria
```
>R 0200          ; Leer byte en $0200
$0200 = $A9

>W 0200 FF       ; Escribir $FF en $0200
$0200 <- $FF

>D 8000 40       ; Dump 64 bytes desde $8000
8000: A9 00 8D 01 C0 A9 C0 8D  03 C0 20 00 90 A2 FF CA  |..........  ....|
```

### Cargar y ejecutar programa
```
>L 0200
Modo carga en $0200 (terminar con '.')
:A9 3F 8D 01 C0 60 .
Cargados 0006 bytes

>M 0200 3
0200  A9 3F     LDA #$3F
0202  8D 01 C0  STA $C001
0205  60        RTS

>G 0200
Ejecutando en $0200...
Retorno de $0200
```

### Usar SD Card
```
>SD
SD Card inicializada OK
Tipo: SDHC

>LS
PROG.BIN      256
TEST.DAT     1024
2 archivos

>SAVE MIPROG.BIN 0200 100
Guardando MIPROG.BIN...
256 bytes guardados

>LOAD MIPROG.BIN 0200
Cargando MIPROG.BIN en $0200...
256 bytes cargados

>G 0200
```

---

## Mapa de Memoria

| Rango | Tamaño | Descripción |
|-------|--------|-------------|
| `$0000-$00FF` | 256 bytes | Zero Page |
| `$0100-$01FF` | 256 bytes | Stack del 6502 |
| `$0200-$3DFF` | ~15 KB | **RAM usuario** (para tus programas) |
| `$3E00-$3FFF` | 512 bytes | Stack de CC65 |
| `$C000-$C0FF` | 256 bytes | Puertos I/O |
| `$8000-$BFFF` | 16 KB | ROM (este monitor) |

**RAM libre para programas:** `$0200-$3DFF` (~15 KB)

---

## Hardware Soportado

| Puerto | Dirección | Descripción |
|--------|-----------|-------------|
| LEDs | `$C001` | 6 LEDs (bits 0-5) |
| LED Config | `$C003` | Configuración E/S (0=salida) |
| SPI Data | `$C010` | Datos SPI (SD Card) |
| SPI Status | `$C011` | Estado SPI |
| SPI CS | `$C012` | Chip Select SD |
| UART Data | `$C020` | Datos TX/RX |
| UART Status | `$C021` | Estado UART |

---

## Estructura del Proyecto

```
├── src/
│   ├── main.c              # Programa principal
│   ├── startup.s           # Código de inicio
│   └── simple_vectors.s    # Vectores NMI, RESET, IRQ
├── libs/                   # Librerías (no incluidas, repos separados)
│   ├── monitor/            # Monitor interactivo
│   ├── uart/               # Comunicación UART
│   ├── spi-6502-cc65/      # Bus SPI
│   ├── sdcard-spi-6502-cc65/  # Driver SD Card
│   └── microfs-6502-cc65/  # Sistema de archivos
├── config/
│   └── fpga.cfg            # Configuración del linker cc65
├── scripts/
│   └── bin2rom3.py         # Conversor BIN → VHDL
├── build/                  # Archivos compilados (generado)
├── output/
│   └── rom.vhd             # ROM generada para FPGA
└── makefile                # Sistema de compilación
```

---

## Instalación

### Requisitos
- [cc65](https://cc65.github.io/) instalado (configurar ruta en makefile)
- Python 3 para el script de conversión
- Librerías en `libs/` (clonar de repos separados):
  - uart
  - spi-6502-cc65
  - sdcard-spi-6502-cc65
  - microfs-6502-cc65
  - monitor

### Compilar
```bash
make
```

### Cargar en FPGA
Copiar `output/rom.vhd` al proyecto FPGA y sintetizar con Gowin EDA.

---

## Crear Programas para el Monitor

Puedes crear programas en **ASM** o **C**, compilarlos y cargarlos vía SD Card.

### Archivo de configuración: programa.cfg

Primero crea este archivo `programa.cfg` que define dónde se cargará el programa en memoria:

```
# programa.cfg - Configuración para programas cargados en $0200
MEMORY {
    RAM: start = $0200, size = $3C00, file = %O;
}
SEGMENTS {
    STARTUP: load = RAM, type = rw;
    CODE:    load = RAM, type = rw;
    RODATA:  load = RAM, type = ro;
    DATA:    load = RAM, type = rw;
    BSS:     load = RAM, type = bss;
}
```

**Explicación:**
- `start = $0200` → El programa se carga en dirección $0200
- `size = $3C00` → Espacio disponible (~15KB hasta $3DFF)
- Los segmentos CODE, DATA, etc. van todos a RAM

### Programa en Ensamblador

```asm
; ejemplo.s
.segment "CODE"

LEDS = $C001

start:
    lda #$3F        ; Encender LEDs
    sta LEDS
    rts             ; Volver al monitor
```

Compilar:
```bash
ca65 -t none -o ejemplo.o ejemplo.s
ld65 -C programa.cfg -o EJEMPLO.BIN ejemplo.o
```

### Programa en C

Para C necesitas un startup mínimo. Crea `crt0.s`:

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
    ; Retornar al monitor
    rts
```

Programa ejemplo `ejemplo.c`:

```c
// ejemplo.c
#define LEDS (*(volatile unsigned char*)0xC001)

void main(void) {
    LEDS = 0x3F;    // Encender LEDs
    // return vuelve al monitor
}
```

Compilar:
```bash
# Compilar el startup (solo una vez)
ca65 -t none -o crt0.o crt0.s

# Compilar el programa C
cc65 -t none -O --cpu 6502 -o ejemplo.s ejemplo.c
ca65 -t none -o ejemplo.o ejemplo.s

# Linkear todo (crt0 primero)
ld65 -C programa.cfg -o EJEMPLO.BIN crt0.o ejemplo.o
```

### Cargar y ejecutar
```
>SD
>LOAD EJEMPLO.BIN 0200
>G 0200
```

Ver documentación completa en `libs/monitor/README.md`

---

## Licencia

MIT
