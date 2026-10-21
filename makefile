# Makefile para 6502 Monitor + SD Card
# Compila main.c con todas las librerías
#
# Compatible con:
#   - make + cmd.exe      (Windows, GnuWin32/nmake-style make)
#   - make + sh           (MSYS2, Git Bash, WSL, Linux, macOS)

# ============================================
# CONFIGURACIÓN DE CC65 - AJUSTAR SEGÚN TU SISTEMA
# ============================================
CC65_HOME = D:\cc65

# ============================================
# DIRECTORIOS
# ============================================
SRC_DIR = src
LIB_DIR = libs
BUILD_DIR = build
OUTPUT_DIR = output
CONFIG_DIR = config
SCRIPTS_DIR = scripts

# ============================================
# VERSIÓN
# ============================================
VERSION = v2.6.4

# ============================================
# HERRAMIENTAS
# ============================================
CC65 = cc65
CA65 = ca65
LD65 = ld65
CL65 = cl65

# ============================================
# DETECCIÓN DE SHELL
# ============================================
# make no expone el shell... así que le hacemos una pregunta cuya respuesta
# solo cmd.exe puede dar: "echo /?" imprime la ayuda de echo ("Syntax:
# ECHO ..."). En sh/bash/..., echo /? escribe "/?".
#
# Regla de oro: esta línea se ejecuta con la sintaxis común a cmd y a sh,
# y además admite make -n (que solo imprime el comando, sin valor útil).
IS_WINDOWS_CMD := $(findstring ECHO,$(shell echo /?))

ifeq ($(IS_WINDOWS_CMD),)
    # ---- sh / bash (MSYS2, Git Bash, WSL, Linux, macOS) ----
    SHELL_EXE       := sh
    PATH_SEP        := :
    DEVNULL         := /dev/null
    DIRS_OK         := test -d $(BUILD_DIR) || mkdir -p $(BUILD_DIR)
    OUTPUT_OK       := test -d $(OUTPUT_DIR) || mkdir -p $(OUTPUT_DIR)
    STAMP_OK        := if ! test -f build/.dirs; then
    STAMP_WRITE     := echo done > build/.dirs; fi
    VERSION_STAMP_WRITE := echo $(VERSION) > build/.version-$(VERSION)
    CLEAN_BUILD     := rm -rf $(BUILD_DIR)
    CLEAN_OUTPUT    := rm -f $(OUTPUT_DIR)/*.vhd $(OUTPUT_DIR)/*.bin $(OUTPUT_DIR)/*.hex
    ECHO_LINE       := echo '========================================'
    PYTHON_POSIX    := $(shell command -v python3 >$(DEVNULL) 2>&1 && echo python3)
else
    # ---- cmd.exe (Windows nativo) ----
    SHELL_EXE       := cmd.exe
    PATH_SEP        := ;
    DEVNULL         := NUL
    DIRS_OK         := if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
    OUTPUT_OK       := if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"
    STAMP_OK        := if not exist build\.dirs
    STAMP_WRITE     := echo done > "$(DIRSTAMP)"
    VERSION_STAMP_WRITE := echo $(VERSION) > "build\.version-$(VERSION)"
    CLEAN_BUILD     := if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
    CLEAN_OUTPUT    := if exist "$(OUTPUT_DIR)\*.vhd" del /q "$(OUTPUT_DIR)\*.vhd" & \
                       if exist "$(OUTPUT_DIR)\*.bin" del /q "$(OUTPUT_DIR)\*.bin" & \
                       if exist "$(OUTPUT_DIR)\*.hex" del /q "$(OUTPUT_DIR)\*.hex"
    ECHO_LINE       := echo ========================================
    PYTHON_POSIX    :=
endif

# Forzar el shell detectado en las recetas (evita que make escoja otro)
ifneq ($(SHELL_EXE),)
    SHELL := $(SHELL_EXE)
    ifeq ($(SHELL_EXE),cmd.exe)
        .SHELLFLAGS := /c
    endif
endif

# ============================================
# SISTEMA DE ARCHIVOS
# ============================================
# cmd.exe no entiende rutas con '/', así que las invertimos cuando van como ARGUMENTO.
# Nota: en este make `$(call ...)` con $1 no funciona dentro de subst, por eso se
# usa $(subst) directamente sobre la ruta.
PATHSEP = $(if $(IS_WINDOWS_CMD),\,/)
TARGET = $(BUILD_DIR)/main.bin

# ============================================
# CONFIGURACIÓN
# ============================================
CONFIG = $(CONFIG_DIR)/fpga.cfg
PLATAFORMA = $(CC65_HOME)\lib\none.lib
CFLAGS = -t none -O --cpu 6502 -DVERSION=\"$(VERSION)\"

# Python: python3 si existe (sh), si no py (lanzador de Windows)
ifeq ($(strip $(PYTHON_POSIX)),)
    PYTHON = py
else
    PYTHON = $(PYTHON_POSIX)
endif

# ============================================
# LIBRERÍAS
# ============================================

UART_DIR = $(LIB_DIR)/uart-6502-cc65
MONITOR_DIR = $(LIB_DIR)/monitor
SPI_DIR = $(LIB_DIR)/spi-6502-cc65
SDCARD_DIR = $(LIB_DIR)/sdcard-spi-6502-cc65
MICROFS_DIR = $(LIB_DIR)/microfs-6502-cc65
TIMER_DIR = $(LIB_DIR)/timer-6502-cc65/src
I2C_DIR = $(LIB_DIR)/i2c-6502-cc65

INCLUDES = -I$(UART_DIR) -I$(MONITOR_DIR) -I$(SPI_DIR) -I$(SDCARD_DIR) -I$(MICROFS_DIR) -I$(TIMER_DIR) -I$(I2C_DIR)

# ============================================
# ARCHIVOS OBJETO
# ============================================
MAIN_OBJ = $(BUILD_DIR)/main.o
UART_OBJ = $(BUILD_DIR)/uart.o
MONITOR_OBJ = $(BUILD_DIR)/monitor.o
STARTUP_OBJ = $(BUILD_DIR)/startup.o
VECTORS_OBJ = $(BUILD_DIR)/simple_vectors.o
SPI_OBJ = $(BUILD_DIR)/spi.o
SDCARD_OBJ = $(BUILD_DIR)/sdcard.o
SDCARD_ASM_OBJ = $(BUILD_DIR)/sdcard_asm.o
MICROFS_OBJ = $(BUILD_DIR)/microfs.o
MICROFS_ASM_OBJ = $(BUILD_DIR)/microfs_asm.o
XMODEM_OBJ = $(BUILD_DIR)/xmodem.o
ROMAPI_OBJ = $(BUILD_DIR)/romapi.o
TIMER_OBJ = $(BUILD_DIR)/timer.o
I2C_OBJ = $(BUILD_DIR)/i2c.o

# microfs_asm.o va AL FINAL a proposito: contiene mfs_streq, cuyo tamano
# cambia con los parches. Si se enlazara antes, su crecimiento desplazaria
# xmodem.o y alteraria el timing de la recepcion XMODEM.
OBJS = $(STARTUP_OBJ) $(MAIN_OBJ) $(UART_OBJ) $(MONITOR_OBJ) $(SPI_OBJ) $(SDCARD_OBJ) $(SDCARD_ASM_OBJ) $(MICROFS_OBJ) $(XMODEM_OBJ) $(ROMAPI_OBJ) $(TIMER_OBJ) $(I2C_OBJ) $(VECTORS_OBJ) $(MICROFS_ASM_OBJ)

# ============================================
# TARGET PRINCIPAL
# ============================================
# Regla por defecto
all: dirs $(TARGET) rom
	@$(ECHO_LINE)
	@echo COMPILADO EXITOSAMENTE
	@$(ECHO_LINE)
	@echo VHDL: $(OUTPUT_DIR)/rom.vhd
	@$(ECHO_LINE)

# Crear directorios (stamp: build/.dirs)
DIRSTAMP = $(BUILD_DIR)/.dirs
$(DIRSTAMP):
	@$(DIRS_OK)
	@$(OUTPUT_OK)
	@$(STAMP_OK) $(STAMP_WRITE)

dirs: $(DIRSTAMP)

# Centinela de version: se reescribe solo cuando cambia VERSION (el nombre
# del archivo incluye la version), lo que fuerza a recompilar main.c y
# monitor.c, que la usan con -DVERSION.
VERSION_STAMP = $(BUILD_DIR)/.version-$(VERSION)
$(VERSION_STAMP): | $(DIRSTAMP)
	@$(VERSION_STAMP_WRITE)

# ============================================
# COMPILACIÓN DE OBJETOS
# ============================================

# Main
$(MAIN_OBJ): $(SRC_DIR)/main.c $(MONITOR_DIR)/monitor.h $(UART_DIR)/uart.h $(VERSION_STAMP) | $(DIRSTAMP)
	$(CC65) $(CFLAGS) $(INCLUDES) -o $(BUILD_DIR)/main.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/main.s

# UART (assembler)
$(UART_OBJ): $(UART_DIR)/uart.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# Monitor
$(MONITOR_OBJ): $(MONITOR_DIR)/monitor.c $(MONITOR_DIR)/monitor.h $(SRC_DIR)/xmodem.h $(UART_DIR)/uart.h \
                $(SDCARD_DIR)/sdcard.h $(MICROFS_DIR)/microfs.h $(VERSION_STAMP) | $(DIRSTAMP)
	$(CC65) $(CFLAGS) $(INCLUDES) -o $(BUILD_DIR)/monitor.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/monitor.s

# Vectores
$(VECTORS_OBJ): $(SRC_DIR)/simple_vectors.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# Startup
$(STARTUP_OBJ): $(SRC_DIR)/startup.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# SPI (assembler)
$(SPI_OBJ): $(SPI_DIR)/spi.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# SDCard
$(SDCARD_OBJ): $(SDCARD_DIR)/sdcard.c $(SPI_DIR)/spi.h | $(DIRSTAMP)
	$(CC65) $(CFLAGS) -I$(SPI_DIR) -o $(BUILD_DIR)/sdcard.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/sdcard.s

$(SDCARD_ASM_OBJ): $(SDCARD_DIR)/sdcard_asm.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# MicroFS
$(MICROFS_OBJ): $(MICROFS_DIR)/microfs.c $(SDCARD_DIR)/sdcard.h | $(DIRSTAMP)
	$(CC65) $(CFLAGS) -I$(SDCARD_DIR) -o $(BUILD_DIR)/microfs.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/microfs.s

$(MICROFS_ASM_OBJ): $(MICROFS_DIR)/microfs_asm.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# XMODEM
$(XMODEM_OBJ): $(SRC_DIR)/xmodem.c $(SRC_DIR)/xmodem.h $(UART_DIR)/uart.h | $(DIRSTAMP)
	$(CC65) $(CFLAGS) $(INCLUDES) -o $(BUILD_DIR)/xmodem.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/xmodem.s

# ROMAPI (Jump Table)
$(ROMAPI_OBJ): $(SRC_DIR)/romapi.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# Timer (assembler) - Usar versión minimal para ahorrar espacio
$(TIMER_OBJ): $(TIMER_DIR)/timer_minimal.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# I2C (assembler)
$(I2C_OBJ): $(I2C_DIR)/i2c.s | $(DIRSTAMP)
	$(CA65) -t none -o $@ $<

# ============================================
# ENLAZADO
# ============================================
$(TARGET): $(OBJS) $(CONFIG)
	$(LD65) -C $(CONFIG) --start-addr 0x8000 -m $(subst /,$(PATHSEP),$(BUILD_DIR)/main.map) -o $@ $(OBJS) $(PLATAFORMA)

# ============================================
# GENERACIÓN DE ROM
# ============================================
rom: $(TARGET)
	$(PYTHON) $(SCRIPTS_DIR)/bin2rom3.py $(subst /,$(PATHSEP),$<) -s 16384 --name rom --data-width 8 --version $(VERSION) -o $(OUTPUT_DIR)

# ============================================
# LIMPIEZA
# ============================================
clean:
	@$(CLEAN_BUILD)
	@$(CLEAN_OUTPUT)

# ============================================
# AYUDA
# ============================================
help:
	@$(ECHO_LINE)
	@echo Comandos
	@$(ECHO_LINE)
	@echo   make        - Compilar y generar ROM
	@echo   make clean  - Limpiar archivos
	@echo   make help   - Mostrar esta ayuda
	@$(ECHO_LINE)

.PHONY: all dirs rom clean help
