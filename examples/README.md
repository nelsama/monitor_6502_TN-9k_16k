# Ejemplos para Monitor 6502

Colección de programas de ejemplo para ejecutar en el Monitor 6502.

## Ejemplos Disponibles

| Carpeta | Descripción | Lenguaje | Dirección |
|---------|-------------|----------|-----------|
| [adventure/](adventure/) | Juego de aventura de texto con SID y LEDs | ASM | $0800 |
| [leds/](leds/) | Efecto Knight Rider con LEDs (plantilla base) | ASM | $0800 |
| [sid/](sid/) | Demo polifónico del chip SID con 3 voces | ASM | $0800 |
| [sidplayer/](sidplayer/) | **Reproductor de archivos .sid** desde SD Card | C+ASM | $2700 |
| [trivia/](trivia/) | Juego de preguntas y respuestas | ASM | $0800 |

## Cómo Usar

### Ejemplos estándar (dirección $0800)
```
LOAD NOMBRE
R
```

### SID Player (dirección $2700)
```
LOAD SIDPLAY 2700
R 2700
```

## SID Player - Reproductor de Música v1.2.1

El **sidplayer** permite reproducir archivos `.sid` (música de Commodore 64):

```
> LOAD SIDPLAY 2700
> R 2700

================================
  SID PLAYER 6502 v1.2.1
  V=VU mode (Max/3ch/Off)
================================

SID (Q=salir, X=XMODEM): COMMANDO
```

**Características:**
- Carga SIDs desde SD Card o XMODEM
- VU meter en LEDs (3 modos)
- Soporta SIDs hasta ~7.75KB

**Controles:** `ESPACIO`=Pausa, `N`/`P`=Siguiente/Anterior, `V`=VU mode, `Q`=Salir

**Nota:** sidplayer usa dirección $2700 porque necesita espacio para los datos SID en $0800-$26FF.

## Crear Tu Propio Ejemplo

1. Copia una carpeta existente (ej: `leds/`)
2. Renómbrala con el nombre de tu proyecto
3. Edita `src/main.s`
4. Compila con `make`

## Estructura de un Ejemplo

```
ejemplo/
├── src/
│   └── main.s          # Código fuente en ensamblador
├── config/
│   └── programa.cfg    # Configuración del linker
├── build/              # Archivos intermedios (generado)
├── output/             # Binario final (generado)
├── makefile            # Script de compilación
└── README.md           # Documentación del ejemplo
```

## Mapa de Memoria

| Rango | Uso |
|-------|-----|
| `$0800-$3DFF` | RAM para programas (default) |
| `$0800-$26FF` | Datos SID (solo sidplayer) |
| `$2700-$3EFF` | SID Player |

## Requisitos

- CC65 toolchain instalado
- Variable de entorno o ruta a CC65 configurada en el makefile
