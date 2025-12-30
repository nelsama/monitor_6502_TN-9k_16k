# Makefile para 6502 Monitor + SD Card
# Compila main.c con todas las librerías

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
# HERRAMIENTAS
# ============================================
CC65 = cc65
CA65 = ca65
LD65 = ld65
CL65 = cl65
PYTHON = py

# ============================================
# CONFIGURACIÓN
# ============================================
CONFIG = $(CONFIG_DIR)/fpga.cfg
PLATAFORMA = $(CC65_HOME)\lib\none.lib
CFLAGS = -t none -O --cpu 6502

# ============================================
# LIBRERÍAS
# ============================================

UART_DIR = $(LIB_DIR)/uart
MONITOR_DIR = $(LIB_DIR)/monitor
SPI_DIR = $(LIB_DIR)/spi-6502-cc65
SDCARD_DIR = $(LIB_DIR)/sdcard-spi-6502-cc65
MICROFS_DIR = $(LIB_DIR)/microfs-6502-cc65

INCLUDES = -I$(UART_DIR) -I$(MONITOR_DIR) -I$(SPI_DIR) -I$(SDCARD_DIR) -I$(MICROFS_DIR)

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

OBJS = $(STARTUP_OBJ) $(MAIN_OBJ) $(UART_OBJ) $(MONITOR_OBJ) $(SPI_OBJ) $(SDCARD_OBJ) $(SDCARD_ASM_OBJ) $(MICROFS_OBJ) $(MICROFS_ASM_OBJ) $(VECTORS_OBJ)

# ============================================
# TARGET PRINCIPAL
# ============================================
TARGET = $(BUILD_DIR)/main.bin

# Regla por defecto
all: dirs $(TARGET) rom
	@echo ========================================
	@echo COMPILADO EXITOSAMENTE
	@echo ========================================
	@echo VHDL: $(OUTPUT_DIR)/rom.vhd
	@echo ========================================

# Crear directorios
dirs:
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"

# ============================================
# COMPILACIÓN DE OBJETOS
# ============================================

# Main
$(MAIN_OBJ): $(SRC_DIR)/main.c
	$(CL65) -t none $(INCLUDES) -c -o $@ $<

# UART
$(UART_OBJ): $(UART_DIR)/uart.c
	$(CC65) $(CFLAGS) -o $(BUILD_DIR)/uart.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/uart.s

# Monitor
$(MONITOR_OBJ): $(MONITOR_DIR)/monitor.c
	$(CC65) $(CFLAGS) $(INCLUDES) -o $(BUILD_DIR)/monitor.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/monitor.s

# Vectores
$(VECTORS_OBJ): $(SRC_DIR)/simple_vectors.s
	$(CA65) -t none -o $@ $<

# Startup
$(STARTUP_OBJ): $(SRC_DIR)/startup.s
	$(CA65) -t none -o $@ $<

# SPI (assembler)
$(SPI_OBJ): $(SPI_DIR)/spi.s
	$(CA65) -t none -o $@ $<

# SDCard
$(SDCARD_OBJ): $(SDCARD_DIR)/sdcard.c
	$(CC65) $(CFLAGS) -I$(SPI_DIR) -o $(BUILD_DIR)/sdcard.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/sdcard.s

$(SDCARD_ASM_OBJ): $(SDCARD_DIR)/sdcard_asm.s
	$(CA65) -t none -o $@ $<

# MicroFS
$(MICROFS_OBJ): $(MICROFS_DIR)/microfs.c
	$(CC65) $(CFLAGS) -I$(SDCARD_DIR) -o $(BUILD_DIR)/microfs.s $<
	$(CA65) -t none -o $@ $(BUILD_DIR)/microfs.s

$(MICROFS_ASM_OBJ): $(MICROFS_DIR)/microfs_asm.s
	$(CA65) -t none -o $@ $<

# ============================================
# ENLAZADO
# ============================================
$(TARGET): $(OBJS)
	$(LD65) -C $(CONFIG) --start-addr 0x8000 -m $(BUILD_DIR)/main.map -o $@ $(OBJS) $(PLATAFORMA)

# ============================================
# GENERACIÓN DE ROM
# ============================================
rom: $(TARGET)
	$(PYTHON) $(SCRIPTS_DIR)/bin2rom3.py $(TARGET) -s 16384 --name rom --data-width 8 -o $(OUTPUT_DIR)

# ============================================
# LIMPIEZA
# ============================================
clean:
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(OUTPUT_DIR)\*.vhd" del /q "$(OUTPUT_DIR)\*.vhd"
	@if exist "$(OUTPUT_DIR)\*.bin" del /q "$(OUTPUT_DIR)\*.bin"
	@if exist "$(OUTPUT_DIR)\*.hex" del /q "$(OUTPUT_DIR)\*.hex"

# ============================================
# AYUDA
# ============================================
help:
	@echo ========================================
	@echo Comandos
	@echo ========================================
	@echo   make        - Compilar y generar ROM
	@echo   make clean  - Limpiar archivos
	@echo   make help   - Mostrar esta ayuda
	@echo ========================================

.PHONY: all dirs rom clean help