# Calabozo del Terror - Aventura de Texto

Un juego de aventura de texto clásico para el Monitor 6502.

## Historia

Despiertas en una celda oscura y húmeda. Debes encontrar la forma de escapar del calabozo, enfrentándote a puertas cerradas y... ¡un dragón!

## Mapa del Calabozo

```
                    [DRAGÓN] ← Guardia la salida
                        |
    [ARMERÍA]---[PASILLO]---[PUERTA] ← Necesita llave
        |           |
      Espada    [CELDA] ← Inicio (tiene llave)
                    |
                [CRIPTA]
```

## Comandos

| Comando | Descripción |
|---------|-------------|
| `N` | Ir al Norte |
| `S` | Ir al Sur |
| `E` | Ir al Este |
| `O` | Ir al Oeste |
| `MIRAR` | Ver descripción de la habitación |
| `COGER` | Tomar objeto de la habitación |
| `INV` | Ver inventario |
| `USAR` | Usar objeto (llave en puerta, espada con dragón) |
| `AYUDA` | Mostrar ayuda |

## Objetos

| Objeto | Ubicación | Uso |
|--------|-----------|-----|
| 🔑 Llave | Celda | Abre la puerta de hierro |
| 🔦 Antorcha | Pasillo | (decorativo) |
| ⚔️ Espada | Armería | Derrota al dragón |

## Solución (SPOILER)

1. `COGER` la llave en la celda
2. `S` ir al pasillo
3. `E` ir a la armería
4. `COGER` la espada
5. `O` volver al pasillo
6. `O` ir a la puerta (si dice "cerrada", sigue al paso 7)
7. `USAR` la llave para abrir
8. `N` ir a la guarida del dragón
9. `USAR` la espada para derrotarlo
10. `S` ¡LIBERTAD!

## LEDs

Los LEDs muestran tu ubicación:
- LED 0: Celda
- LED 1: Pasillo
- LED 2: Armería
- LED 3: Cripta
- LED 4: Puerta
- LED 5: Dragón
- TODOS: ¡Victoria!

## Compilar

```bash
make        # Compilar
make info   # Ver tamaño (~2.6KB)
make clean  # Limpiar
```

## Usar en el Monitor

```
SD                      ; Inicializar SD Card
LOAD ADVENT.BIN 0400    ; Cargar juego
G 0400                  ; ¡Jugar!
```

## Tamaño

**2652 bytes** - Cabe perfectamente en RAM ($0400-$3DFF)
