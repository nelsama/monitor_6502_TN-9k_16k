# Ejemplo SID + LEDs - Demo de Efectos de Sonido

Demo espectacular que combina efectos de sonido del chip SID con animaciones coordinadas en los LEDs.

## Descripción

Este programa demuestra las capacidades del SID con **8 efectos** diferentes, cada uno con su propia animación de LEDs sincronizada:

| # | Efecto | Sonido | LEDs |
|---|--------|--------|------|
| 1 | **Barrido ascendente** | Frecuencia subiendo (Sawtooth) | Secuenciales izq→der |
| 2 | **Arpegio rápido** | Notas C-E-G-C veloces (Pulse) | LED por nota |
| 3 | **Explosión** | Ruido blanco con decay | Todos ON → fade out |
| 4 | **Sirena** | Frecuencia oscilante (Triangle) | Ping-pong |
| 5 | **Bajo + Melodía** | "Oda a la Alegría" + bajo | LED según nota bajo |
| 6 | **Barrido descendente** | Frecuencia bajando (Sawtooth) | Rotativos der→izq |
| 7 | **Acordes** | C-G-Am-F con 3 voces | Pattern por acorde |
| 8 | **Final épico** | Escala con 3 voces en armonía | Acumulativos + fade |

## Hardware Utilizado

### Chip SID ($D400-$D41C)

| Registro | Dirección | Descripción |
|----------|-----------|-------------|
| V1 Freq Lo/Hi | $D400-$D401 | Frecuencia voz 1 |
| V1 PW Lo/Hi | $D402-$D403 | Ancho de pulso voz 1 |
| V1 Control | $D404 | Waveform + gate |
| V1 AD/SR | $D405-$D406 | Envolvente ADSR |
| V2 ... | $D407-$D40D | Voz 2 (misma estructura) |
| V3 ... | $D40E-$D414 | Voz 3 (misma estructura) |
| Mode/Vol | $D418 | Modo filtro y volumen master |

### LEDs ($C001)

- 6 LEDs conectados a bits 0-5
- Activos en bajo (escribir 0 = LED encendido)
- `$00` = todos ON, `$3F` = todos OFF

## Formas de Onda

| Bit | Valor | Forma de onda | Uso en este demo |
|-----|-------|---------------|------------------|
| 4 | $10 | Triangular | Sirena, acordes |
| 5 | $20 | Diente de sierra | Barridos, bajo |
| 6 | $40 | Pulso | Melodía, arpegio |
| 7 | $80 | Ruido | Explosión |

## Patrones de LEDs

| Patrón | Descripción |
|--------|-------------|
| Secuencial | 1→2→4→8→16→32 |
| Ping-pong | 1→2→4→8→16→32→16→8→4→2→1 |
| Fade out | 000000→100000→110000→...→111111 |
| Acumulativo | 1→3→7→15→31→63 |

## Compilar

```bash
make        # Compilar
make info   # Ver tamaño (~985 bytes)
make clean  # Limpiar
```

## Usar en el Monitor

```
SD                      ; Inicializar SD Card
LOAD SID.BIN 0400       ; Cargar programa
G 0400                  ; Ejecutar
```

El programa se repite en loop infinito. Presiona **RESET** para detener.

## Estructura del Código

```
start           → Punto de entrada, llama a sid_init
main_loop       → Loop principal, ejecuta los 8 efectos
sid_init        → Limpia registros SID, volumen máximo
effect_sweep_up → Efecto 1: barrido ascendente
effect_fast_arpeggio → Efecto 2: arpegio rápido
effect_explosion → Efecto 3: explosión de ruido
effect_siren    → Efecto 4: sirena
effect_bass_melody → Efecto 5: bajo + melodía
effect_sweep_down → Efecto 6: barrido descendente
effect_chords   → Efecto 7: acordes con 3 voces
effect_finale   → Efecto 8: final épico
```

## Tablas de Datos

Las frecuencias y patrones de LEDs están en tablas al final:

```asm
arp_freq_lo/hi  ; Notas para arpegio (C-E-G-C)
led_arp         ; LEDs para cada nota del arpegio
led_fade        ; Secuencia de fade out
melody_freq_lo/hi ; "Oda a la Alegría"
bass_freq_lo/hi ; Notas del bajo
chord_root/third/fifth ; Acordes (raíz, tercera, quinta)
finale_freq_lo/hi ; Escala final ascendente
```

## Tamaño

**985 bytes** - Cabe en la RAM disponible ($0400-$3DFF)
