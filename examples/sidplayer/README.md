# SID Player para Monitor 6502

Reproductor de archivos .sid (PSID v1/v2) para el Monitor 6502 con chip SID.

## Características

- **Compatible con PSID v1/v2**: Formato estándar de archivos SID
- **Carga desde SD o XMODEM**: Dos formas de cargar SIDs
- **Multi-canción**: Navega entre canciones del archivo
- **Info en pantalla**: Muestra título, autor y copyright
- **Controles intuitivos**: Pausa, siguiente, anterior
- **VU meter en LEDs**: 3 modos (Max/3ch/Off) con envolventes del SID
- **Timing preciso**: Usa timer hardware para 60Hz (NTSC)
- **Usa ROM API**: No incluye librerías, las llama desde ROM (~5.5KB)

## Compatibilidad

### ✅ Funciona con SIDs que:
- **Cargan en $1000** (dirección estándar de demoscene)
- **Tamaño < 7.75KB** (para no chocar con el player en $2700)
- **Zero Page en $80-$EF** (o que no usen ZP)
- playAddress != 0 (no-IRQ, polling)

### ✅ Ejemplos compatibles:
- Melodías clásicas: Commando, Wizball, Last Ninja, Ikari Warriors
- Compositores: Rob Hubbard, Martin Galway, Ben Daglish, Jeroen Tel, Laxity
- SIDs de demos/intros (generalmente cargan en $1000)

### ❌ NO funciona con SIDs que:
- Cargan fuera de $1000 (ej: $5000, $AE00, $BFF0) - fuera del RAM de 16KB
- Usan Zero Page por debajo de $80 (conflicto con monitor/CC65)
- Requieren más de 7.75KB de datos
- Usan samples digitalizados (digi-samples)
- Requieren 2SID/Stereo
- Necesitan IRQ real (este player usa polling a 60Hz)

## Mapa de Memoria

```
$0000-$01FF  Zero Page y Stack del sistema
$0200-$07FF  Variables del monitor
$0800-$26FF  ← Datos SID (máx ~7.75KB)
$2700-$3EFF  ← SID Player (~6KB)
$3F00-$3FFF  Stack del player
$8000-$BEFF  ROM Monitor
$BF00-$BFF9  ROM API (Jump Table)
$BFFA-$BFFF  Vectores 6502
$D400-$D41F  Chip SID (+ registros extendidos $D41D-$D41F)
```

## Uso

### 1. Preparar archivos
```bash
# Compilar el reproductor
cd examples/sidplayer
make

# Copiar a la SD Card
copy output\sidplay.bin X:\SIDPLAY

# Copiar archivos .sid (nombres 8.3)
copy *.sid X:\
```

### 2. Ejecutar
```
En el monitor:

> LOAD SIDPLAY 2700
SIDPLAY cargado, ~5.5KB
> R 2700

================================
  SID PLAYER 6502 v1.2.0
  V=VU mode (Max/3ch/Off)
================================

SID (Q=salir, X=XMODEM): IKARI     <- nombre de archivo en SD
SID (Q=salir, X=XMODEM): X         <- recibe por XMODEM
```

### 3. Controles durante reproducción
| Tecla | Función |
|-------|---------|
| ESPACIO | Pausa / Continuar |
| N | Siguiente canción |
| P | Canción anterior |
| V | Cambiar modo VU meter |
| 1-9 | Ir a canción específica |
| Q | Volver al menú principal |

### Modos VU meter (tecla V)
| Modo | Descripción |
|------|-------------|
| Max | 6 LEDs muestran el máximo de las 3 voces |
| 3ch | 2 LEDs por canal (V1=LED1-2, V2=LED3-4, V3=LED5-6) |
| Off | LEDs apagados |

## ROM API

Este programa usa la ROM API del monitor (jump table en $BF00).
No necesita incluir las librerías SD/MicroFS/UART.

### Funciones usadas:
```
$BF03 - mfs_mount()      Montar sistema de archivos
$BF06 - mfs_open()       Abrir archivo
$BF27 - mfs_read_ext()   Leer datos (parámetros en ZP $F0-$F3)
$BF0C - mfs_close()      Cerrar archivo
$BF0F - mfs_get_size()   Obtener tamaño
$BF18 - uart_putc()      Enviar carácter
$BF1B - uart_getc()      Recibir carácter
$BF21 - uart_rx_ready()  Verificar RX
```

### mfs_read_ext ($BF27)
Función especial para programas externos que evita conflictos con el 
software stack de CC65. Los parámetros se pasan en posiciones fijas de ZP:

```
$F0-$F1 = puntero al buffer destino
$F2-$F3 = cantidad de bytes a leer
Retorna: A/X = bytes leídos
```

## Compilación

```bash
cd examples/sidplayer
make clean
make
```

Requiere:
- CC65 instalado (CC65_HOME configurado en makefile)
- Monitor con ROM API (jump table en $BF00)

## Notas Técnicas

### Timing
- Usa timer hardware en $C038-$C03C
- 60Hz NTSC = 16,667 µs por frame
- Llamada a play() cada frame

### SID
- Base: $D400
- 25 registros (3 voces + filtro)
- Limpieza de registros antes de cada canción

### Formato PSID
- Header: 76-124 bytes
- Direcciones en big-endian
- init = inicialización (A = número canción)
- play = llamar cada frame

## Archivos

```
sidplayer/
├── src/
│   ├── main.c          # Código principal
│   ├── sid_player.s    # Funciones ASM (incluyendo rom_read_file wrapper)
│   └── startup.s       # Inicialización CC65
├── config/
│   └── programa.cfg    # Linker config ($2700)
├── makefile
└── README.md
```

## Changelog

### v1.2.1 (2026-01-13)
- Player movido a $2700 (antes $2600)
- SIDs ahora pueden usar hasta ~7.75KB (antes ~7.5KB)
- Corregido límite en XMODEM para coincidir con nuevo layout

### v1.2.0 (2026-01-13)
- VU meter en LEDs con 3 modos seleccionables (tecla V)
  - Max: 6 LEDs muestran máximo de 3 voces
  - 3ch: 2 LEDs por canal (visualiza cada voz)
  - Off: LEDs apagados
- LEDs apagados al inicio, en pausa y al cambiar canción
- Usa registros extendidos SID ($D41D-$D41F) para envelopes
- Optimización de memoria (buffer reducido)

### v1.1.0 (2026-01-08)
- Soporte XMODEM para cargar SIDs por serial
- Usa ROM API xmodem_receive ($BF2A)
- Buffer reducido de 512 a 256 bytes

### v1.0.0 (2026-01-08)
- Timing ajustado a 60Hz (NTSC)
- Pausa silencia el SID correctamente
- Salida al monitor con Q funciona
- `sid_clear()` mejorado (apaga gates antes de limpiar)
- Documentación de compatibilidad de SIDs
- Usa ROM API con mfs_read_ext
- Soporte multi-canción (N/P/1-9)
- LEDs sincronizados con la música
