# Ejemplo SID Polifónico - Demo de 3 Voces

Demo que demuestra las capacidades polifónicas del chip SID usando las 3 voces simultáneamente con LEDs sincronizados.

## Descripción

Este programa demuestra las capacidades del SID con **4 efectos** polifónicos:

| # | Efecto | Descripción | LEDs |
|---|--------|-------------|------|
| 1 | **Barrido polifónico** | 3 voces (Saw+Pulse+Tri) barriendo frecuencias | Knight rider |
| 2 | **Acordes** | Progresión C-G-Am-F con 3 voces | LED por acorde |
| 3 | **Arpegio rápido** | Notas C-E-G alternando entre voces | LED por voz activa |
| 4 | **Melodía + Bajo + Ritmo** | "Oda a la Alegría" con acompañamiento | Secuencial |

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
| Acumulativo | 1→3→7→15→31→63 |

## Compilar

```bash
make        # Compilar
make info   # Ver tamaño
make clean  # Limpiar
```

## Usar en el Monitor

```
LOAD SID               ; Cargar desde SD
G 0800                 ; Ejecutar
```

O via XMODEM:
```
XRECV 0800             ; Recibir programa
G 0800                 ; Ejecutar
```

El programa se repite en loop infinito. Presiona **RESET** para detener.

## Estructura del Código

```
start              → Punto de entrada, inicializa SID
main_loop          → Loop principal, ejecuta los 4 efectos
sid_init           → Limpia registros, configura 3 voces
effect_sweep_poly  → Efecto 1: barrido con 3 voces (Saw+Pulse+Tri)
effect_chords      → Efecto 2: progresión de acordes C-G-Am-F
effect_arpeggio    → Efecto 3: arpegio rápido alternando voces
effect_melody      → Efecto 4: melodía + bajo + percusión
```

## Voces del SID

| Voz | Forma de Onda | Uso |
|-----|---------------|-----|
| V1 | Pulse | Melodía principal |
| V2 | Sawtooth | Bajo/acordes |
| V3 | Triangle/Noise | Armonía/percusión |

## Tamaño

~800 bytes - Carga en $0800
