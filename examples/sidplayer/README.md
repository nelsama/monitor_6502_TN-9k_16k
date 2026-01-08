# SID Player para Monitor 6502

Reproductor de archivos .sid (PSID v1/v2) para el Monitor 6502 con chip SID.

## Características

- **Compatible con PSID v1/v2**: Formato estándar de archivos SID
- **Carga desde SD o XMODEM**: Dos formas de cargar SIDs
- **Multi-canción**: Navega entre canciones del archivo
- **Info en pantalla**: Muestra título, autor y copyright
- **Controles intuitivos**: Pausa, siguiente, anterior
- **LEDs sincronizados**: Efectos visuales durante reproducción
- **Timing preciso**: Usa timer hardware para 60Hz (NTSC)
- **Usa ROM API**: No incluye librerías, las llama desde ROM (~5.5KB)

## Compatibilidad

### ✅ Funciona con SIDs que:
- **Cargan en $1000** (dirección estándar de demoscene)
- **Tamaño < 5.5KB** (para no chocar con el player en $2600)
- **Zero Page en $80-$EF** (o que no usen ZP)
- playAddress != 0 (no-IRQ, polling)

### ✅ Ejemplos compatibles:
- Melodías clásicas: Commando, Wizball, Last Ninja, Ikari Warriors
- Compositores: Rob Hubbard, Martin Galway, Ben Daglish, Jeroen Tel, Laxity
- SIDs de demos/intros (generalmente cargan en $1000)

### ❌ NO funciona con SIDs que:
- Cargan fuera de $1000 (ej: $5000, $AE00, $BFF0) - fuera del RAM de 16KB
- Usan Zero Page por debajo de $80 (conflicto con monitor/CC65)
- Requieren más de 5.5KB de datos
- Usan samples digitalizados (digi-samples)
- Requieren 2SID/Stereo
- Necesitan IRQ real (este player usa polling a 60Hz)

## Mapa de Memoria

```
$0000-$01FF  Zero Page y Stack del sistema
$0200-$07FF  Variables del monitor
$0800-$25FF  ← Datos SID (máx ~7.5KB)
$2600-$3CFF  ← SID Player (~5KB)
$3D00-$3DFF  Stack del player
$8000-$BEFF  ROM Monitor
$BF00-$BFF9  ROM API (Jump Table)
$BFFA-$BFFF  Vectores 6502
$D400-$D41F  Chip SID
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

> LOAD SIDPLAY 2600
SIDPLAY cargado, 5439 bytes
> R 2600

================================
  SID PLAYER 6502 v1.1.0
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
| 1-9 | Ir a canción específica |
| Q | Volver al menú principal |

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
│   └── programa.cfg    # Linker config ($2600)
├── makefile
└── README.md
```

## Changelog

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
