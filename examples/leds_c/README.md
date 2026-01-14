# Plantilla de Programa en C para Monitor 6502

Este proyecto es una **plantilla** para crear programas en C que se ejecutan sobre el Monitor 6502 en la Tang Nano 9K.

## Características

- ✅ Programa en C usando cc65
- ✅ Usa **ROM API** para UART y Timer (no incluye librerías)
- ✅ Tres efectos de LEDs (Knight Rider, alternado, secuencial)
- ✅ Timing preciso con timer hardware
- ✅ Código compacto (~2KB)
- ✅ Totalmente funcional como plantilla

## Estructura del Proyecto

```
leds_c/
├── src/
│   ├── main.c          # Código fuente principal
│   └── startup.s       # Código de inicio del runtime C
├── config/
│   └── programa.cfg    # Configuración del linker
├── build/              # Archivos objeto (generados)
├── output/             # Binario final (generado)
├── makefile            # Script de compilación
└── README.md           # Este archivo
```

## Requisitos

- **CC65** instalado en `D:\cc65` (o ajustar ruta en makefile)
- **Monitor 6502 v2.2.0+** con ROM API en $BF00
- **SD Card** para transferir el programa (o usar XMODEM)

## Compilación

```bash
# Compilar el programa
make

# Limpiar archivos generados
make clean

# Ver tamaño del binario
make info

# Ver mapa de memoria
make map
```

## Uso

### Vía SD Card
1. Compilar con `make`
2. Copiar `output/leds_c.bin` a la SD Card como `LEDS_C`
3. En el monitor:
   ```
   SD                      ; Inicializar SD
   LOAD LEDS_C             ; Cargar programa (default: $0800)
   R                       ; Ejecutar
   ```

### Vía XMODEM
```
XRECV                   ; Recibir via XMODEM (default: $0800)
R                       ; Ejecutar
```

## Efectos Implementados

El programa rota automáticamente entre tres efectos:

1. **Knight Rider**: Luz que va y viene (como el auto de la serie)
2. **Alternado**: LEDs parpadean en patrón alternado
3. **Secuencial**: Enciende LEDs uno por uno

Para salir, presionar `CTRL+C` o resetear el monitor.

## Mapa de Memoria

| Rango | Uso |
|-------|-----|
| `$0002-$001F` | Zero Page del Monitor (NO USAR) |
| `$0020-$007F` | Zero Page disponible para programas |
| `$0100-$01FF` | Stack del 6502 (compartido) |
| `$0200-$07FF` | BSS del Monitor (NO USAR) |
| `$0800-$3DFF` | RAM para programas (código, datos, BSS) |
| `$3E00-$3FFF` | Stack de CC65 (512 bytes) |
| `$C000-$C0FF` | Puertos de I/O |
| `$BF00-$BF2F` | ROM API (Jump Table) |

## Puertos de Hardware

```c
#define LEDS    (*(volatile uint8_t *)0xC001)   /* LEDs (lógica negativa) */
#define TIMER   (*(volatile uint8_t *)0xC030)   /* Timer hardware */
```

**LEDs**: 6 bits (0-5), lógica negativa (0=encendido, 1=apagado)  
**Timer**: Incrementa ~60 veces por segundo

## ROM API Utilizada

Este programa usa la **ROM API** del monitor, lo que permite:
- ✅ Código más compacto (~777 bytes vs ~1224 bytes con implementación propia)
- ✅ Sin conflictos con el estado del monitor
- ✅ No necesita incluir librerías UART/Timer

### Funciones usadas:

| Dirección | Función | Uso en el programa |
|-----------|---------|-------------------|
| `$BF18` | `uart_putc(char)` | Enviar caracteres al terminal |
| `$BF2D` | `get_micros()` | Leer contador de microsegundos |
| `$BF30` | `delay_us(us)` | Delays en microsegundos |
| `$BF33` | `delay_ms(ms)` | Delays en milisegundos |

Para usar otras funciones de la ROM API, consultar [`include/romapi.h`](../../include/romapi.h) en la raíz del proyecto.

## Crear un Nuevo Programa

1. Copiar esta carpeta completa
2. Renombrar el proyecto
3. Editar `src/main.c` con tu código
4. Ajustar `PROGRAM_NAME` en el makefile si deseas otro nombre
5. Compilar con `make`

## Ejemplo: Controlar LEDs desde C

```c
#include <stdint.h>

#define LEDS (*(volatile uint8_t *)0xC001)

void mi_funcion(void) {
    /* Encender todos los LEDs */
    LEDS = 0x00;    /* Lógica negativa */
    
    /* Apagar todos */
    LEDS = 0xFF;
    
    /* Patrón personalizado (bits 0,2,4 encendidos) */
    LEDS = ~0x15;   /* 010101 invertido */
}
```

## Ejemplo: Llamar ROM API desde C

```c
/* Incluir el header de ROM API */
#include "../../../include/romapi.h"

/* Usar en tu código */
void mi_funcion(void) {
    rom_uart_putc('H');        /* Enviar caracter */
    rom_delay_ms(100);         /* Delay de 100ms */
    
    /* Otras funciones disponibles */
    rom_uart_puts("Hello\n");  /* Enviar string */
    uint32_t t = rom_get_micros();  /* Leer microsegundos */
    rom_delay_us(500);         /* Delay de 500 microsegundos */
}
```

**Nota**: El header `romapi.h` define todas las funciones ROM disponibles con sus prototipos correctos. Ver [`include/romapi.h`](../../include/romapi.h) para la lista completa.

## Diferencias con la Versión en Ensamblador

| Característica | Ensamblador | C |
|----------------|-------------|---|
| Tamaño | ~300 bytes | ~2KB |
| Velocidad | Más rápido | Aceptable |
| Facilidad | Más complejo | Más fácil |
| Mantenimiento | Difícil | Fácil |
| Funciones C | No | Sí (strings, math, etc.) |

**Recomendación**: Usar C para programas complejos, ensamblador para código crítico o muy pequeño.

## Notas Importantes

- El código **inicia en $0800** (segmento STARTUP)
- Usar **Zero Page $20-$7F** para variables (no $02-$1F)
- Los LEDs usan **lógica negativa** (0=encendido)
- El stack de CC65 está en **$3E00-$3FFF** (512 bytes)
- `main()` debe retornar para volver al monitor

## Resolución de Problemas

**Error al compilar**: Verificar que CC65_HOME apunte a la instalación de cc65

**Programa no carga**: Verificar que la dirección sea $0800 en el comando LOAD

**LEDs no funcionan**: Recordar que usan lógica negativa (0=encendido)

**Crashes al ejecutar**: Verificar que no se use Zero Page $02-$1F (reservada por monitor)

## Ver También

- [examples/leds/](../leds/) - Versión en ensamblador (más compacta)
- [examples/sidplayer/](../sidplayer/) - Ejemplo avanzado en C usando ROM API
- [include/romapi.h](../../include/romapi.h) - Documentación completa de ROM API
- [README.md principal](../../README.md) - Documentación del monitor

## Licencia

Este proyecto está licenciado bajo la **GNU General Public License v3.0**.
