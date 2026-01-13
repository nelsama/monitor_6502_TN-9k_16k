# Plantilla de Programa en Ensamblador para Monitor 6502

Este proyecto es una **plantilla** para crear programas en ensamblador que se ejecutan sobre el Monitor 6502 en la Tang Nano 9K.

## Estructura del Proyecto

```
leds/
├── src/
│   └── main.s          # Código fuente principal
├── config/
│   └── programa.cfg    # Configuración del linker
├── build/              # Archivos objeto (generados)
├── output/             # Binario final (generado)
├── makefile            # Script de compilación
└── README.md           # Este archivo
```

## Requisitos

- **CC65** instalado en `D:\cc65` (o ajustar ruta en makefile)
- **Monitor 6502** corriendo en la Tang Nano 9K
- **SD Card** para transferir el programa

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

1. Compilar con `make`
2. Copiar `output/leds.bin` a la SD Card
3. En el monitor:
   ```
   SD                      ; Inicializar SD
   LOAD LEDS               ; Cargar programa
   R                       ; Ejecutar
   ```

## Mapa de Memoria

| Rango | Uso |
|-------|-----|
| `$0002-$001F` | Zero Page del Monitor (NO USAR) |
| `$0020-$007F` | Zero Page disponible para programas |
| `$0100-$01FF` | Stack del 6502 (compartido) |
| `$0200-$07FF` | BSS del Monitor (NO USAR) |
| `$0800-$3DFF` | RAM para programas |
| `$3E00-$3FFF` | Stack de CC65 |
| `$C000-$C0FF` | Puertos de I/O |

## Puertos de Hardware

```asm
LEDS = $C001    ; Puerto de LEDs (6 bits, lógica negativa)
                ; Bit 0-5: LEDs, 0=encendido, 1=apagado
```

## Ejemplo: Escribir a LEDs

```asm
    ; Encender todos los LEDs
    lda #$00        ; 0 = todos encendidos (lógica negativa)
    sta $C001

    ; Apagar todos los LEDs
    lda #$FF        ; FF = todos apagados
    sta $C001

    ; Patrón alternado
    lda #$AA        ; 10101010
    sta $C001
```

## Crear un Nuevo Proyecto

1. Copiar esta carpeta completa
2. Renombrar el proyecto
3. Editar `src/main.s` con tu código
4. Ajustar `PROGRAM_NAME` en el makefile si deseas otro nombre
5. Compilar con `make`

## Notas Importantes

- El código **inicia en $0800** (segmento STARTUP)
- Usar **Zero Page $20-$7F** para variables (no $02-$1F)
- Los LEDs usan **lógica negativa** (0=encendido)
- El programa puede usar `JSR`/`RTS` normalmente (stack $0100-$01FF)
- Para volver al monitor, terminar con `RTS`

## Efectos Incluidos en main.s

1. **Knight Rider** - Luz que va y viene (efecto principal)
2. **Parpadeo** - Todos los LEDs parpadean
3. **Contador binario** - Cuenta de 0 a 63

## Licencia

MIT License - Libre para usar y modificar.
