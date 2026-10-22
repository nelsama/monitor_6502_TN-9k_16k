# Bug: `mfs_streq` distingue mayúsculas, los nombres 8.3 no deberían

Estado: **reproducido y con parche probado** (pendiente de integrar en la librería)
Fecha: 2026-10-21
Reportado desde: `monitor_6502_TN-9k_16k` (monitor v2.6.3)
Reproducido en: emulador FPGA 6502 (SD con MicroFS)

---

## 1. Resumen

`mfs_streq()` compara cadenas byte a byte, por lo que **distingue mayúsculas de
minúsculas**. Cualquier archivo creado por un programa que no normalice los
nombres (por ejemplo, uno que llame a `mfs_create("juego.bin")`) queda
**inaccesible** para quien lo busque en mayúsculas.

Consecuencia práctica: el monitor 6502 normaliza los nombres a mayúsculas
(`parse_filename()`), así que `DEL juego.bin`, `LOAD juego.bin` y
`CAT juego.bin` fallaban con `Error: 03` (NOTFOUND) sobre un archivo que
existía en la SD.

---

## 2. Entorno donde se detectó

| Elemento | Versión / detalle |
|---|---|
| Monitor | v2.6.3 (`monitor_6502_TN-9k_16k`) |
| MicroFS | `microfs-6502-cc65`, commit `6d00986` |
| Hardware | Tang Nano 9K (GW1NR-9), 6502 @ 3.375 MHz |
| Emulación | Emulador FPGA 6502 (para la reproducción controlada) |

---

## 3. Reproducción

### 3.1 Crear un archivo en minúsculas

El monitor no puede hacerlo (normaliza a mayúsculas), así que hay dos vías:

**a) Desde un programa externo:**

```c
/* programa cargado en $0800, usando la ROM API o la librería */
mfs_create("juego.bin", 64);
mfs_write(datos, 64);
mfs_close();
```

**b) Manipulando la imagen de la SD** (lo usado para el test):

```
Entrada de tabla MicroFS en el sector 0, offset 16 + i*32:
  +0..11  nombre, ASCII terminado en NUL   <- escribir "juego.bin"
  +12..13 sector inicial (LE)
  +14..15 tamaño en bytes (LE)
  +16..17 sectores reservados (LE)
```

### 3.2 Intentar borrarlo desde el monitor

```
> ls
...
  juego.bin  64 bytes

> del juego.bin
Error: 03
```

El archivo sigue ahí. `Error: 03` es `MFS_ERR_NOTFOUND`.

---

## 4. Causa raíz

### 4.1 `microfs_asm.s` — `_mfs_streq` (versión original)

```asm
_mfs_streq:
        sta     ptr2
        stx     ptr2+1
        jsr     popax
        sta     ptr1
        stx     ptr1+1

        ldy     #0
@loop:  lda     (ptr1),y
        cmp     (ptr2),y        ; comparación exacta, sensible al case
        bne     @diff
        cmp     #0
        beq     @equal
        iny
        bne     @loop
@diff:  lda     #0
        ldx     #0
        rts
@equal: lda     #1
        ldx     #0
        rts
```

### 4.2 `microfs.c` — consumidores

`mfs_streq` se usa en tres rutas, todas afectadas:

| Línea | Función | Efecto del bug |
|---|---|---|
| `microfs.c:72` | `mfs_open` | `LOAD`/`CAT` no encuentran el archivo |
| `microfs.c:99` | `mfs_create` (¿existe ya?) | puede crear **duplicados** lógicos |
| `microfs.c:262` | `mfs_delete` | `DEL` no encuentra el archivo |

### 4.3 El factor que lo destapa

El monitor normaliza a mayúsculas en `parse_filename()`
(`libs/monitor/monitor.c`):

```c
if (c >= 'a' && c <= 'z') c -= 32;  /* A mayúsculas */
```

Sin esa normalización el bug también existiría, pero solo se manifestaría al
mezclar nombres con distinto case.

---

## 5. Impacto

| Aspecto | Detalle |
|---|---|
| **Gravedad** | Media-alta para archivos creados por terceros |
| **Alcance** | Toda la API de MicroFS (`open`/`create`/`delete`) |
| **Pérdida de datos** | No: el archivo permanece, solo es inaccesible |
| **Recuperación** | Manual (formatear o renombrar con la herramienta de SD) |
| **Frecuencia** | Alta si algún programa escribe nombres sin normalizar |

En FAT (el estándar de facto en SD) los nombres 8.3 son **case-insensitive**,
así que el comportamiento actual tampoco es coherente con el sistema de
archivos que se está emulando.

---

## 6. Parche propuesto

Comparar primero exacto (camino rápido) y, si difiere, reintentar normalizando
solo letras ASCII a minúscula con `OR $20`, validando que el resultado caiga en
`'a'..'z'` para no confundir bytes no alfabéticos.

### 6.1 Código

Archivo: `microfs_asm.s`, función `_mfs_streq`

```asm
;-----------------------------------------------------------------------------
; _mfs_streq - Comparar dos strings (sin distinguir mayúsculas)
; uint8_t mfs_streq(const char *a, const char *b)
; Retorna: 1 si iguales, 0 si diferentes
;
; La comparación ignora el case SOLO en letras ASCII (A-Z / a-z), que es
; lo que necesita un nombre 8.3. Cualquier otro byte debe coincidir exacto.
;-----------------------------------------------------------------------------
_mfs_streq:
        sta     ptr2            ; b low
        stx     ptr2+1          ; b high
        jsr     popax
        sta     ptr1            ; a low
        stx     ptr1+1          ; a high

        ldy     #0
@loop:  lda     (ptr1),y
        cmp     (ptr2),y
        beq     @same           ; iguales exactos: camino rápido

        ; Distintos: normalizar a minúscula con OR $20 y comparar.
        ; Solo vale para letras: tras OR $20 el resultado debe caer en
        ; $61-$7A ('a'-'z'). Si no, no era una letra y son distintos.
        ora     #$20
        cmp     #$61
        bcc     @diff
        cmp     #$7B
        bcs     @diff
        sta     tmp1
        lda     (ptr2),y
        ora     #$20
        cmp     tmp1
        bne     @diff

@same:  lda     (ptr1),y        ; recargar: cmp pudo dejar A en (ptr2)
        cmp     #0              ; ¿Fin de string?
        beq     @equal
        iny
        bne     @loop           ; Max 256 chars
@diff:  lda     #0
        ldx     #0
        rts
@equal: lda     #1
        ldx     #0
        rts
```

### 6.2 Por qué se recarga `A` en `@same`

En el camino exacto (`beq @same`), `A` contiene `(ptr1),y` y el `cmp #0`
funciona. Pero tras el camino case-insensitive, `A` quedó con el valor de
`(ptr2),y`, así que hay que recargar `(ptr1),y` antes de comprobar NUL.
Mantener una sola salida ahorra bytes frente a duplicar el bloque.

### 6.3 Validación de la lógica

Simulación en Python de la semántica del ASM parcheado (11 casos):

| a | b | Esperado | Obtenido |
|---|---|---|---|
| `JUEGO.BIN` | `JUEGO.BIN` | igual | ✅ |
| `JUEGO.BIN` | `juego.bin` | igual | ✅ |
| `juego.bin` | `JUEGO.BIN` | igual | ✅ |
| `AB` | `A` | distinto | ✅ |
| `A` | `AB` | distinto | ✅ |
| `''` | `''` | igual | ✅ |
| `a@` | `` a` `` | distinto | ✅ |
| `TEST.TXT` | `test.txt` | igual | ✅ |
| `[` | `{` | distinto | ✅ |
| `@` | `` ` `` | distinto | ✅ |

**0 fallos.** El chequeo de rango evita que bytes como `'@'` (0x40) se
confundan con `` '`' `` (0x60).

---

## 7. Pruebas en el emulador

| Caso | Antes | Después |
|---|---|---|
| `del juego.bin` (archivo en minúsculas) | `Error: 03` | ✅ `Eliminado` |
| `del test.txt` (minúsculas) | `Error: 03` | ✅ `Eliminado` |
| `del SIDPLAY.BIN` (mayúsculas) | ✅ | ✅ sin regresión |
| `del NOEXISTE.BIN` | `Error: 03` | ✅ `Error: 03` |

Verificación adicional en la ROM compilada:

```
09 20  c9 61  90 17  c9 7b  b0 13  85 1e  b1 18  09 20  c5 1e
ora #$20  cmp #$61  bcc  cmp #$7B  bcs  sta tmp1 ...
```

El código parcheado está efectivamente enlazado.

> **Nota sobre la dirección:** al principio de la depuración este bloque estaba
> en `$AC9A`. El commit `36af6b1` movió `microfs_asm.o` al final del enlace para
> que el tamaño de `mfs_streq` no desplazara `xmodem.o`, así que ahora vive en
> **`$B13F`**. Para comprobarlo, buscar el **patrón** (`09 20 c9 61`) y no una
> dirección fija: entre builds el código se mueve.
>
> Verificación con la ROM actual (md5 `69f0c2dafddb`): patrón encontrado en
> `$B13F`. ✅

---

## 8. Coste

| Métrica | Antes | Después | Delta |
|---|---|---|---|
| `microfs_asm.o` | 38 B | 74 B | **+36 B** |

En el monitor v2.6.3 el ROM sigue cabiendo: quedan **402 bytes** libres hasta
`$BEFF` (los segmentos con dirección fija `ROMAPI`/`VECTORS` limitan la zona
utilizable).

---

## 9. Alternativas consideradas

### 9.1 Normalizar al crear y al abrir (rechazada)

Que `mfs_create` convierta a mayúsculas el nombre y `mfs_open`/`mfs_delete`
hagan lo mismo. Funciona, pero:

- Hay que tocar tres rutas en vez de una
- Los archivos ya creados en minúsculas **seguirían inaccesibles**
- Gasta más ROM

### 9.2 Búsqueda en dos pasadas desde el llamador (rechazada)

Desde el monitor: buscar exacto y, si falla, reintentar con la variante
opuesta. Conserva la distinción de case, pero:

- Aumenta el tamaño del monitor, no de la librería (donde está el defecto)
- No arregla el problema para otros consumidores de MicroFS
- Permite coexistir `juego.bin` y `JUEGO.BIN`, lo que complica el modelo

### 9.3 Parche elegido

`mfs_streq` case-insensitive: un solo punto, arregla `open`/`create`/`delete`
a la vez, y alinea con FAT 8.3.

---

## 10. Compatibilidad

| Escenario | Efecto |
|---|---|
| SD con nombres solo en mayúsculas (lo habitual) | Sin cambios |
| SD con nombres en minúsculas | Pasan a ser accesibles |
| SD con `juego.bin` **y** `JUEGO.BIN` | **Colisionan**: se resuelve al primero que aparezca en la tabla |

> Este último punto es el único cambio de comportamiento observable. Se
> considera aceptable porque FAT 8.3 tampoco permite dos entradas que solo
> difieran en case, y el monitor ya normaliza a mayúsculas.

---

## 11. Archivos afectados

| Archivo | Cambio |
|---|---|
| `microfs_asm.s` | `_mfs_streq` pasa a comparar ignorando case |
| `microfs.c` | sin cambios |
| `microfs.h` | sin cambios (la firma no cambia) |

---

## 12. Tareas

- [ ] Aplicar el parche en `microfs_asm.s` del repositorio
- [ ] Actualizar el README de la librería con la nota de case-insensitive
- [ ] Añadir una nota en `MFS_MAX_FILES`/formato sobre nombres 8.3
- [ ] (Opcional) Documentar en `mfs_create` que el nombre se guarda tal cual
- [ ] (Opcional) Test automatizado: crear `a.bin`, abrir `A.BIN`, borrar `a.Bin`

---

## Anexo A: parche local ya aplicado

Durante la depuración se aplicó el parche **solo en la copia local del
monitor**, que no se versiona:

```
D:\Proyectos\monitor_6502_TN-9k_16k\libs\microfs-6502-cc65\microfs_asm.s
```

Esa ruta está excluida por `.gitignore` (`libs/*`), así que **el cambio se
perderá si se recopian las librerías**. Este documento existe precisamente
para poder reaplicarlo aquí:

```
D:\Proyectos\libs\microfs-6502-cc65\microfs_asm.s
```

Comparación de ambas copias en el momento del informe:

| Ruta | Tamaño | Fecha | Parche |
|---|---|---|---|
| `monitor_...\libs\microfs-6502-cc65\microfs_asm.s` | 3117 B | 21 oct 14:24 | ✅ |
| `D:\Proyectos\libs\microfs-6502-cc65\microfs_asm.s` | 2307 B | 17 oct 11:19 | ❌ |
