# Dungeon Adventure - Juego de Mazmorras 6502

Un juego de aventura de texto clásico para el Monitor 6502.

## Historia

Entras en una mazmorra antigua buscando el legendario tesoro del rey.
Explora las habitaciones, encuentra objetos útiles y escapa con el oro!

## Mapa de la Mazmorra

```
         [CRIPTA]
            |
  [ARMERÍA]-[SALON]-[CELDA]
            |         🔑
        [ENTRADA]
            |
       [PASILLO]---[TESORO] 🔒💰
            |
        [TRAMPA]
            |
        [SALIDA]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `N` | Ir al Norte |
| `S` | Ir al Sur |
| `E` | Ir al Este |
| `W` | Ir al Oeste |
| `L` | Mirar (ver descripción) |
| `I` | Ver inventario |
| `G` | Coger objeto |
| `H` | Mostrar ayuda |
| `Q` | Salir (vuelve al monitor) |

## Objetos

| Objeto | Ubicación | Uso |
|--------|-----------|-----|
| 🔑 Llave | Celda | Abre la puerta al tesoro |
| 🔦 Antorcha | Armería | Ilumina la cripta oscura |
| 💰 Oro | Sala del Tesoro | ¡El objetivo! |

## Puzzles

1. **Puerta cerrada**: La sala del tesoro está cerrada. Encuentra la llave en la celda.
2. **Cripta oscura**: No puedes entrar sin una antorcha (en la armería).
3. **Escapar**: Debes tener el oro para ganar al llegar a la salida.

## Efectos de Sonido (SID)

| Evento | Sonido |
|--------|--------|
| Inicio | Arpegio ascendente C-E-G-C |
| Caminar | Ruido de pasos (3 pasos) |
| Recoger objeto | Tono triangular ascendente |
| Encontrar tesoro | Fanfarria especial |
| Puerta cerrada | Sonido metálico |
| Bloqueado | Tono descendente |
| Victoria | ¡Fanfarria épica! |

## Indicadores LED

Los 6 LEDs muestran el estado del juego:

| LED | Significado |
|-----|-------------|
| 0-2 | Número de habitación (binario) |
| 3 | Tienes la llave |
| 4 | Tienes la antorcha |
| 5 | Tienes el oro |

## Solución (SPOILER)

```
N       ; Entrada -> Gran Salón
E       ; Salón -> Celda
G       ; Coger LLAVE
W       ; Celda -> Salón
W       ; Salón -> Armería
G       ; Coger ANTORCHA
E       ; Armería -> Salón
S       ; Salón -> Entrada
S       ; Entrada -> Pasillo
E       ; Pasillo -> Tesoro (usa la llave automáticamente)
G       ; Coger ORO
W       ; Tesoro -> Pasillo
S       ; Pasillo -> Trampa
S       ; Trampa -> Salida = ¡VICTORIA!
```

## Compilación

```bash
cd examples/adventure
make clean
make
```

## Uso en el Monitor

```
LOAD ADVENT
R
```

## Hardware Utilizado

- **SID** ($D400): Efectos de sonido
- **Timer** ($C038): Delays precisos en milisegundos
- **LEDs** ($C001): Indicadores de estado
- **UART** ($C020): Entrada/salida de texto

## Notas Técnicas

- Tamaño: ~3KB de código
- RAM: Variables en Zero Page
- Dirección de carga: $0800
