# Monitor 6502 v2.6.2

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
- ✅ **SD montada automáticamente** al iniciar
- ✅ **Auto-boot**: ejecuta programa automático desde SD
- ✅ **XMODEM**: transferencia de archivos desde PC
- ✅ **ROM API**: funciones del sistema disponibles para programas externos
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
| `$BF00-$BF83` | 132 bytes | ROM API (Jump Table) |

## Formato de Parámetros

**Todo en HEXADECIMAL** (sin prefijo `$` ni `0x`):
- `addr` = dirección de 4 dígitos (ej: `0800`, `C001`, `8000`)
- `len` = longitud en bytes (ej: `10`=16, `100`=256, `1000`=4096)
- `val` = valor de 1 byte (ej: `FF`, `A9`, `00`)

---

## Comandos Básicos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **R** | `R [addr]` | Ejecutar programa (default: última dirección usada) |
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
| **SD** | `SD` | (Opcional) Inicializar SD Card (se monta sola al inicio) |
| **LS** | `LS` | Listar archivos |
| **SAVE** | `SAVE file addr len` | Guardar memoria a archivo |
| **LOAD** | `LOAD file addr` | Cargar archivo a memoria |
| **DEL** | `DEL file` | Eliminar archivo |
| **CAT** | `CAT file` | Ver contenido en hex |
| **SDFMT** | `SDFMT` | Formatear SD Card |

## Otros Comandos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| **H** | `H` | Ayuda general |
| **H** | `H cmd` | Ayuda detallada del comando |
| **Q** | `Q` | Salir del monitor (reset) |

---

## SD Card - Ejemplos

### Inicializar y listar
```
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

>R
Ejecutando en $0800...
```

---

## ROM API

La ROM expone funciones en `$BF00-$BF83` para que programas externos (como el SID Player) puedan acceder a SD, UART, SPI, I2C y timer sin incluir librerías.

Ver la documentación completa en `include/romapi.h` o en el README principal del proyecto.

---

## Notas Técnicas

- **Buffer de entrada**: 64 caracteres máximo por línea
- **RAM usable**: `$0800-$3DFF` (~14KB para tus programas)
- **Retorno al monitor**: Tu código debe terminar con `RTS` ($60)
- **SD Card**: Nombres hasta 12 caracteres (ej: `PROG.BIN`, `LAUNCHER.BIN`)
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
