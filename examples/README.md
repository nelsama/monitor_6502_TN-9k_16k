# Ejemplos para Monitor 6502

Colección de programas de ejemplo para ejecutar en el Monitor 6502.

## Ejemplos Disponibles

| Carpeta | Descripción | Lenguaje | Dirección |
|---------|-------------|----------|-----------|
| [adventure/](adventure/) | Juego de aventura de texto con SID y LEDs | ASM | $0800 |
| [leds/](leds/) | Efecto Knight Rider con LEDs (plantilla base) | ASM | $0800 |
| [leds_c/](leds_c/) | Efectos LED con ROM API (temporizador, UART) | C | $0800 |
| [sid/](sid/) | Demo polifónico del chip SID con 3 voces | ASM | $0800 |
| [trivia/](trivia/) | Juego de preguntas y respuestas | ASM | $0800 |

## Cómo Usar

### Todos los ejemplos (dirección $0800)
```
LOAD NOMBRE
R
```

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
| `$0800-$3DFF` | RAM para programas de usuario |
| `$0200-$07FF` | Reservado para el monitor (BSS) |

## Requisitos

- CC65 toolchain instalado
- Variable de entorno o ruta a CC65 configurada en el makefile
