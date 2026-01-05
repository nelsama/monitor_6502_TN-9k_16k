# Ejemplos para Monitor 6502

Colección de programas de ejemplo para ejecutar en el Monitor 6502.

## Ejemplos Disponibles

| Carpeta | Descripción |
|---------|-------------|
| [leds/](leds/) | Efecto Knight Rider con LEDs (plantilla base) |

## Cómo Usar

1. Entra a la carpeta del ejemplo
2. Compila con `make`
3. Copia el `.bin` a la SD Card
4. En el monitor:
   ```
   SD
   LOAD NOMBRE.BIN 0400
   G 0400
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

## Requisitos

- CC65 toolchain instalado
- Variable de entorno o ruta a CC65 configurada en el makefile
