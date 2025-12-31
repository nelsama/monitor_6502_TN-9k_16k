# Makefile para programa de LEDs - Monitor 6502
# Tang Nano 9K con cc65

# Configuración cc65 - Ajustar si es necesario
CC65_HOME = D:\cc65

# Herramientas
CC = $(CC65_HOME)\bin\cc65.exe
CA = $(CC65_HOME)\bin\ca65.exe
LD = $(CC65_HOME)\bin\ld65.exe

# Directorios
SRC_DIR = src
CONFIG_DIR = config
BUILD_DIR = build
OUTPUT_DIR = output

# Flags
CC_FLAGS = -t none -O
CA_FLAGS = -t none
LD_FLAGS = -C $(CONFIG_DIR)/programa.cfg

# Archivos fuente
C_SOURCES = $(SRC_DIR)/main.c
ASM_SOURCES = $(SRC_DIR)/runtime.s

# Archivos objeto
C_OBJECTS = $(BUILD_DIR)/main.o
ASM_OBJECTS = $(BUILD_DIR)/runtime.o
ALL_OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

# Programa de salida
PROGRAM = $(OUTPUT_DIR)/leds.bin
MAP_FILE = $(OUTPUT_DIR)/leds.map

# Regla principal
all: dirs $(PROGRAM)

# Crear directorios
dirs:
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	@if not exist $(OUTPUT_DIR) mkdir $(OUTPUT_DIR)

# Compilar C a ensamblador, luego ensamblar
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c
	$(CC) $(CC_FLAGS) -o $(BUILD_DIR)/main.s $<
	$(CA) $(CA_FLAGS) -o $@ $(BUILD_DIR)/main.s

# Ensamblar runtime
$(BUILD_DIR)/runtime.o: $(SRC_DIR)/runtime.s
	$(CA) $(CA_FLAGS) -o $@ $<

# Enlazar - IMPORTANTE: runtime.o primero para que STARTUP vaya primero
$(PROGRAM): $(ALL_OBJECTS)
	$(LD) $(LD_FLAGS) -o $@ -m $(MAP_FILE) $(ASM_OBJECTS) $(C_OBJECTS)
	@echo.
	@echo ========================================
	@echo Programa generado: $(PROGRAM)
	@echo Mapa de memoria: $(MAP_FILE)
	@echo ========================================
	@echo.
	@echo Para cargar en el monitor:
	@echo   1. Copiar leds.bin a la SD
	@echo   2. En el monitor: LOAD LEDS.BIN
	@echo   3. Ejecutar: G 0400
	@echo.

# Limpiar
clean:
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
	@if exist $(OUTPUT_DIR) rmdir /s /q $(OUTPUT_DIR)

# Ver información del binario
info: $(PROGRAM)
	@echo Tamanio del programa:
	@dir $(PROGRAM) | findstr leds.bin

# Mostrar mapa de memoria
map: $(PROGRAM)
	@type $(MAP_FILE)

.PHONY: all dirs clean info map
