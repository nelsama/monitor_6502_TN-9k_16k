# SID Player para Monitor 6502

Reproductor de archivos .sid (PSID v1/v2) para el Monitor 6502 con chip SID.

## Características

- **Compatible con PSID v1/v2**: Formato estándar de archivos SID
- **Multi-canción**: Navega entre canciones del archivo
- **Info en pantalla**: Muestra título, autor y copyright
- **Controles intuitivos**: Pausa, siguiente, anterior
- **LEDs sincronizados**: Efectos visuales durante reproducción
- **Timing preciso**: Usa timer hardware para 50Hz exactos

## Compatibilidad

### ✅ Funciona bien con:
- Melodías clásicas de C64 (Commando, Wizball, Last Ninja...)
- Compositores: Rob Hubbard, Martin Galway, Ben Daglish, Jeroen Tel
- SIDs que usan timing PAL estándar (50Hz)
- Archivos con playAddress != 0 (no-IRQ)

### ⚠️ Limitaciones:
- No soporta samples digitalizados (digi-samples)
- No soporta 2SID/Stereo
- No IRQ (solo polling a 50Hz)
- Algunos efectos de filtro pueden sonar diferente

## Uso

### 1. Preparar archivos
```
# Copiar el reproductor a la SD Card
copy output\sidplay.bin X:\SIDPLAY

# Copiar archivos .sid (nombres 8.3)
copy *.sid X:\
```

### 2. Ejecutar
```
En el monitor:

> LOAD SIDPLAY
SIDPLAY cargado, 4567 bytes
> R

================================
  SID PLAYER 6502
  Para archivos PSID v1/v2
================================

Montando SD Card...
SD Card OK!

Archivo .sid (Q=salir): COMMANDO
```

### 3. Controles durante reproducción
| Tecla | Función |
|-------|---------|
| `ESPACIO` | Pausa / Continuar |
| `N` | Siguiente canción |
| `P` | Canción anterior |
| `1-9` | Ir a canción específica |
| `Q` | Volver al menú |

## Compilación

```batch
cd examples\sidplayer
make
```

Genera: `output/sidplay.bin`

## Formato PSID

El reproductor parsea el header PSID:
```
Offset  Tamaño  Campo
------  ------  -----
$00     4       Magic ("PSID" o "RSID")
$04     2       Versión (big-endian)
$06     2       Offset a datos
$08     2       Load Address
$0A     2       Init Address
$0C     2       Play Address
$0E     2       Número de canciones
$10     2       Canción inicial
$12     4       Flags de velocidad
$16     32      Nombre
$36     32      Autor
$56     32      Copyright
```

## Obtener archivos SID

Los archivos .sid se pueden descargar de:
- [HVSC](https://www.hvsc.c64.org/) - High Voltage SID Collection (90,000+ SIDs)
- [DeepSID](https://deepsid.chordian.net/) - Reproductor web con búsqueda

### Recomendaciones para empezar:
```
COMMANDO.SID    - Rob Hubbard
WIZBALL.SID     - Martin Galway  
LASTNIN2.SID    - Ben Daglish
CYBERNOI.SID    - Jeroen Tel
BUBBLE.SID      - Varios
```

## Notas técnicas

- **Timer**: Usa $C038-$C03C (contador microsegundos) para timing
- **SID**: Escribe directamente a $D400-$D418
- **RAM**: Carga SID en $3000+ (deja espacio para el player)
- **LEDs**: Actualiza $C001 con patrón rotativo

## Troubleshooting

**"Error: No es archivo PSID/RSID"**
- El archivo no tiene header válido o está corrupto

**"Error: SID no cabe en RAM"**  
- El SID es muy grande o tiene loadAddress conflictivo

**No hay sonido**
- Verificar que el archivo tenga playAddress != 0
- Algunos SIDs RSID requieren IRQ (no soportado)

**Suena mal/rápido**
- El SID puede usar timing NTSC (60Hz) - suena 20% más rápido
