# Respuesta al informe: posible bug en la ROM API del monitor 6502

**Fecha**: 2026-10-21
**Origen de la respuesta**: proyecto `monitor_6502_TN-9k_16k`
**Versión analizada**: v2.6.4 (`eaa762e`)
**Veredicto general**: la hipótesis principal **no se sostiene**, pero el informe
acertó en un defecto real de documentación, que ya está corregido.

---

## 0. Resumen para quien no lea el resto

| Punto del informe | Veredicto | Evidencia |
|---|---|---|
| D1: magic en `$BF87` pero el header dice `$BF84` | ❌ **Falso** (en parte) | `romapi.h` decía `0xBF87`; **el comentario de cabecera** sí erraba. Corregido |
| D2: la tabla puede estar incompleta en v2.6.4 | ❌ **Falso** | Volcado completo: **44/44 entradas son `JMP` válidos** |
| D4: no se documenta la preservación de registros | ✅ **Cierto** | Documentación añadida en el commit `eaa762e` |
| §3: las rutinas de `$BF00` no preservan registros y eso explica el síntoma | ⚠️ **Correcto el hecho, incorrecta la consecuencia** | `uart_rx_ready`/`uart_getc` solo destruyen A y X, que en fastcall **son de retorno** |
| H2: el espacio sobre casilla vacía no selecciona por diseño | ✅ **Coincide con nuestra lectura** | Es la explicación más probable |
| H4: el `.bin` probado no incluye el header nuevo | ✅ **Probablemente cierto** | Recomendamos recompilar antes de concluir nada |

**No hay evidencia de un bug en la ROM API.** El único defecto real es de
documentación y ya está resuelto.

---

## 1. Verificación de la jump table (D1 y D2)

Volcado de `$BF00-$BFEF` desde `output/rom.vhd` de la v2.6.4:

```
$BF00   4C 3F A0      JMP $A03F     sd_init
$BF03   4C E7 A3      JMP $A3E7     mfs_mount
$BF06   4C D4 BF      JMP $BFD4     mfs_open      (wrapper ZP en ROM)
$BF09   4C 8E BF      JMP $BF8E     mfs_read      (wrapper ZP en ROM)
...
$BF84   4C 19 AC      JMP $AC19     mfs_seek
$BF87   52 4F 4D 41 50 49   "ROMAPI"            <- magic
$BF8E   ...           wrapper mfs_read
```

Conclusiones:

1. **Todas las entradas declaradas en `romapi.h`** (`ROMAPI_*`) apuntan a un
   `JMP` válido. Se verificaron las 44 una por una.
2. Los `JMP` cuyo destino es `$BF8E`, `$BF9C`, `$BFAA`, `$BFBF`, `$BFD4`,
   `$BFDB`, `$BFE2` **no son un error**: son los *wrappers* de cero page, que
   viven en la propia zona `$BF00-$BFEF`. Es intencionado.
3. **El magic está en `$BF87`**, y `romapi.h` ya lo declaraba como `0xBF87`:

```c
#define ROMAPI_MAGIC_ADDR       0xBF87
```

El error estaba únicamente en el **comentario de cabecera**, que decía
`MAGIC: $BF84 - "ROMAPI" v2.4`. Corregido.

4. El comentario decía también **"38 funciones"**. Son **44**. Corregido.

---

## 2. Sobre la hipótesis de no reentrancia (§3)

### 2.1 Lo que es cierto

Ninguna entrada de la tabla guarda y restaura los registros del llamante.
Verificado en `uart.s`:

```asm
.proc _uart_rx_ready
    lda     UART_STATUS     ; A -> destruido
    and     #UART_RX_VALID
    beq     @no_data
    lda     #$01
@no_data:
    ldx     #$00            ; X -> destruido
    rts
.endproc

.proc _uart_puts
    sta     ptr1            ; ptr1 ($16) -> destruido
    stx     ptr1+1
    ldy     #$00            ; Y -> destruido
    ...
@done:
    rts                     ; Y = longitud de la cadena al retornar
.endproc
```

### 2.2 Por qué **no** explica el síntoma

El informe razona así:

> "Si `w` funciona, el byte llega. Si el espacio no funciona, algo ocurre entre
> la llegada del byte y la comparación de la línea 26."

Ese razonamiento asume que `rom_uart_rx_ready()` altera el byte leído. Pero:

```
bf21 -> JMP $80E8   ==  _uart_rx_ready
bf1b -> JMP $80DB   ==  _uart_getc
```

`_uart_rx_ready` **no toca zero page** y solo destruye A y X. En la convención
CC65, **A y X son registros de retorno**: cualquier compilador CC65 asume que se
destruyen tras un `JSR`. El valor leído por `_uart_getc` está en **A** y se
copia a una local inmediatamente:

```c
c = rom_uart_getc();        // el compilador sabe que solo A/X son válidos
if (c == ' ')  return KEY_SPACE;
```

No hay ninguna ruta por la que el espacio se convierta en otro valor.

### 2.3 El caso que sí es peligroso (y por eso lo documentamos)

`uart_puts` **sí** pisa `ptr1` y `Y`. Si un programa C mantiene un puntero vivo
en `ptr1` mientras llama a `rom_uart_puts()`, se corrompe. Es una trampa real,
aunque **no la del síntoma reportado**.

Por eso se añadió la sección "PRESERVACION DE REGISTROS" al `romapi.h`.

---

## 3. Sobre la afirmación de §3.3 ("por qué afecta solo al espacio")

No hay mecanismo que lo sostenga. Si `_uart_rx_ready` corrompiera el byte:

- `w` (`0x77`) y `s` (`0x73`) también saldrían alterados, o
- saldrían alterados de forma no determinista.

El informe describe `w` y `s` como **perfectamente estables** (`52→44`,
`44→52`, repetido 3 veces). Un registro corrompido no da ese patrón: da errores
aleatorios.

---

## 4. La explicación más simple (H2) — coincidimos

El propio informe la identifica y ella misma la descarta sin motivo:

```c
if (g_selected_sq == 0xFF) {
    if (!IS_EMPTY(g_state.board[g_cursor_sq]) &&
        COLOR_OF(...) == g_state.side) {
        g_selected_sq = g_cursor_sq;
```

Con el cursor en `e3` (44) o `e4` (36), **ambas casillas están vacías al
inicio** en ajedrez. `IS_EMPTY()` es verdadero, la condición es falsa y **no se
selecciona nada**. Eso es correcto, no un bug.

> El informe probó exactamente los dos casos en los que el comportamiento
> esperado y el observado **coinciden**. Las teclas de movimiento (`w`/`s`)
> funcionan porque no dependen del contenido de la casilla.

### Prueba que recomendamos (30 segundos)

1. Arrancar el juego (el cursor empieza en `e2` = 52, con peón blanco).
2. Pulsar **espacio sin mover el cursor**.
3. Comprobar si la pieza queda seleccionada (debería marcarse).
4. Mover con `w`/`s` sobre `e2`, `d2`, `f2`... y probar espacio en cada una.

Si el espacio selecciona sobre piezas y no sobre casillas vacías, **el juego
funciona como está diseñado**.

---

## 5. Prueba P2 propuesta: innecesaria, pero posible

El informe propone un test ASM de 20 líneas para medir preservación de
registros. Ya la hemos hecho por inspección (sección 2.1) y el resultado es el
esperado para funciones fastcall: **A/X se destruyen, es la convención**.

Si aun así se quiere una verificación empírica, el test correcto no es
"¿se preservan los registros?" (no deben), sino:

```
¿devuelve _uart_getc el byte correcto?
   para cada byte b en 0x00..0xFF:
       escribir b en $C020
       llamar $BF1B
       comparar A con b
```

Ese es el test que descartaría corrupción real. Nos consta que en v2.6.4 el
camino es `JMP $80DB` → `lda $C020` → `ldx #0` → `rts`, sin manipulación
intermedia.

---

## 6. Defectos reales detectados en el informe y ya corregidos

| # | Defecto | Corrección |
|---|---|---|
| 1 | Comentario decía `MAGIC: $BF84` | Ahora `$BF87` |
| 2 | Comentario decía "38 funciones" | Ahora 44 |
| 3 | No había sección de preservación de registros | Añadida, con A/X/Y/P y el detalle de zero page por función |

### Contenido añadido (resumen)

```
A, X  -> SON DE RETORNO. Se destruyen siempre.
Y     -> NO garantizado. uart_puts termina con Y = longitud.
P     -> puede cambiar.

uart_puts ($BF1E) escribe ptr1 y ptr1+1.  <- CUIDADO
mfs_read ($BF09), mfs_read_ext ($BF27) usan $F0-$F3.
mfs_list ($BF12), mfs_create ($BF3C), mfs_write ($BF3F),
mfs_load_file ($BF7E), mfs_load_run ($BF81),
sd_read_sector ($BF72), sd_write_sector ($BF75) usan $F4-$F7.

Las funciones que solo leen hardware (uart_rx_ready, uart_tx_ready,
spi_receive, sd_is_ready...) no tocan zero page: solo A y X.
```

Commit: `eaa762e` — "Document ROM API register preservation and fix header errors".

---

## 7. Respuesta a H4 (binario desactualizado)

Tiene razón en la observación y es el punto más importante del informe:

> `output/chess.bin` es de las 09:41 y `romapi.h` se actualizó a las 18:54.

Si el `.bin` no se recompiló con el header nuevo, **ninguna conclusión sobre la
ROM API es válida**. Recomendamos:

1. Recompilar el ajedrez con el `romapi.h` actual (`eaa762e`).
2. Volver a reproducir el caso **sobre una pieza**, no sobre casilla vacía.
3. Solo entonces, si el espacio sigue sin funcionar sobre pieza propia,
   reabrir el análisis con ese dato.

---

## 8. Sugerencias al proyecto del ajedrez (fuera de nuestro ámbito)

1. **Mostrar un feedback visible** al pulsar espacio sobre casilla vacía
   (parpadeo, sonido, mensaje). Un `no-op` silencioso se confunde con un bug.
2. **Recompilar siempre** tras actualizar `romapi.h`.
3. Si el juego usa `rom_uart_puts` en rutinas con punteros vivos, revisar que
   no dependa de `ptr1` ni de `Y` después de la llamada.

---

## 9. Conclusión

- **No hay bug demostrado en la ROM API.**
- El defecto de documentación que sí existía (preservación de registros) está
  corregido en `eaa762e`.
- Dos afirmaciones verificadas del informe (D1 parcial y D2) son incorrectas.
- La hipótesis principal no explica el síntoma: los registros afectados son de
  retorno por convención, y el patrón observado (estable en `w`/`s`) no encaja
  con corrupción de registros.
- La causa más probable sigue siendo **H2**: probar espacio sobre casillas
  vacías, donde no seleccionar es el comportamiento correcto.

**Acción pedida al agente del ajedrez**: repetir la prueba con el cursor sobre
`e2` (peón blanco) antes de dar por cierta cualquier conclusión sobre la ROM.

---

## 10. Anexo: aclaración sobre la dirección del parche `mfs_streq`

Segunda ronda de revisión. El agente comparó el bytecode del parche entre
ROMs y concluyó:

> "El parche está solo en el binario del emulador, no en el fuente del monitor
> ni en la ROM del proyecto."

**Esa conclusión es incorrecta**, aunque la observación de partida (las ROMs
no coincidían) **sí era válida** y destapó un problema real.

### 10.1 Lo que era cierto: el emulador tenía una ROM vieja

| Archivo | md5 (antes) | Commit equivalente |
|---|---|---|
| `fpga-6502-16k/src/rom.vhd` | `69f0c2da` | actual |
| `monitor/output/rom.{bin,vhd}` | `69f0c2da` | actual |
| `EmuladorFpga6502/rom/monitor.bin` | **`f3a34540`** | `a347f23` (previo a los fixes) |

El binario del emulador estaba desfasado: le faltaban el fix de XMODEM
(`36af6b1`) y el reordenamiento del enlace. **Ya está sincronizado.**

### 10.2 Lo que era incorrecto: el parche SÍ está en la ROM del FPGA

El agente buscó `09 20 c9 61` en la **dirección `$AC9A`** de ambas ROMs y no
lo encontró en la del FPGA. Pero esa dirección ya no es la correcta:

```
FPGA  ($AC9A): c9 3c b0 57 a9 15 ...   <- otro codigo
EMU   ($AC9A): c9 7b b0 13 85 1e ...   <- parche
```

El commit `36af6b1` movió `microfs_asm.o` **al final del enlace** para que el
tamaño de `mfs_streq` no desplazara `xmodem.o` (era justo la causa de la
lentitud de XMODEM). Eso reubicó la función:

| ROM | `mfs_streq` en |
|---|---|
| Emulador (enlace antiguo) | `$AC94` |
| FPGA (enlace nuevo) | **`$B13F`** |

Buscando el **patrón** en lugar de una dirección fija:

```python
parche = bytes([0x09, 0x20, 0xC9, 0x61])   # ora #$20 / cmp #$61

FPGA  rom.vhd          -> encontrado en $B13F  OK
Emulador monitor.bin   -> encontrado en $AC94  OK
```

**Ambas ROMs tienen el parche.** El fuente `libs/microfs-6502-cc65/microfs_asm.s`
lo contiene, y el repo de la librería lo tiene commiteado (`3ee0c4c`).

### 10.3 Nota metodológica para futuras comprobaciones

Comparar ROMs **por dirección absoluta** no es fiable entre builds: cualquier
cambio de tamaño o de orden de enlace desplaza el código, y eso es
precisamente lo que se hizo a propósito.

Lo correcto es:

```python
img.find(bytes([0x09, 0x20, 0xC9, 0x61]))   # buscar el patron
```

Y para verificar que una ROM es la esperada, comparar el **md5 completo**:

```
69f0c2dafddb  <- v2.6.4 con XMODEM corregido y parche mfs_streq
```

Cualquier ROM con otro md5 es otra build y no debe usarse para concluir nada
sobre el firmware actual.
