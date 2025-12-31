# Programa de Demostración LEDs

Efecto de luces LED para el Monitor 6502 en Tang Nano 9K.

## Estructura

```
leds/
├── config/
│   └── programa.cfg    # Configuración de memoria para ld65
├── src/
│   ├── main.c          # Programa principal con efectos de LEDs
│   └── runtime.s       # Runtime mínimo cc65 (sin libc)
├── build/              # Archivos intermedios (generado)
├── output/             # Binario final (generado)
├── makefile
└── README.md
```

## Requisitos

- **cc65**: Toolchain para 6502
- **CC65_HOME**: Variable en makefile apuntando a la instalación de cc65

## Compilación

```bash
make
```

## Uso

1. Copiar `output/leds.bin` a la tarjeta SD
2. Insertar SD en la FPGA
3. En el monitor:
   ```
   LOAD LEDS.BIN
   G 0400
   ```

## Efectos incluidos

1. **Knight Rider** - Luz que va y viene
2. **Contador binario** - Cuenta de 0 a 63
3. **Parpadeo alterno** - LEDs alternos parpadean
4. **Llenado progresivo** - Se llenan y vacían los LEDs
5. **Parpadeo todos** - Todos los LEDs parpadean juntos

## Mapa de memoria

| Segmento  | Dirección | Descripción |
|-----------|-----------|-------------|
| ZEROPAGE  | $02-$FE   | Variables ZP (sp, ptr1) |
| STARTUP   | $0400     | Inicialización del stack |
| CODE      | $0400+    | Código del main.c |
| RUNTIME   | después   | Funciones de runtime |
| RODATA    | después   | Constantes |
| DATA      | después   | Variables inicializadas |
| BSS       | después   | Variables sin inicializar |

## Notas técnicas

- El runtime incluye solo las funciones necesarias para código simple
- No incluye printf ni ninguna función de libc
- Los LEDs están en `$C001` y son activos en bajo
- El stack de cc65 se inicializa en `$3DFF`

## Crear tu propio programa

Modifica `src/main.c` con tu código. Asegúrate de:

1. No usar funciones de libc (printf, malloc, etc.)
2. Usar solo operaciones básicas de C
3. Acceder al hardware mediante punteros volátiles
4. El programa puede ser un bucle infinito o terminar con `return`

### Ejemplo mínimo

```c
#define LEDS (*(volatile unsigned char *)0xC001)

int main(void) {
    LEDS = 0xAA;    // Encender LEDs alternos
    while(1);       // Bucle infinito
    return 0;
}
```

## Solución de problemas

### El programa no arranca
- Verificar que el binario se cargó en $0400
- Usar `D 0400 0450` para ver si hay código
- La primera instrucción debe inicializar el stack

### Los efectos son muy rápidos/lentos
- Ajustar `delay_long()` en main.c
- Aumentar/disminuir el parámetro de las funciones de efecto
