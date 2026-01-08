# Makefile para Adventure - Juego de Aventura de Texto
# Monitor 6502 - Tang Nano 9K

# Herramientas CC65
CC65_PATH = D:/cc65
CA65 = $(CC65_PATH)/bin/ca65
LD65 = $(CC65_PATH)/bin/ld65

# Directorios
SRC_DIR = src
BUILD_DIR = build
OUTPUT_DIR = output
CONFIG_DIR = config

# Archivos
TARGET = $(OUTPUT_DIR)/advent.bin
MAP_FILE = $(BUILD_DIR)/advent.map
SRC = $(SRC_DIR)/main.s
OBJ = $(BUILD_DIR)/main.o
CFG = $(CONFIG_DIR)/programa.cfg

# Reglas
all: dirs $(TARGET)
	@echo ========================================
	@echo COMPILADO: $(TARGET)
	@echo ========================================
	@echo Para usar:
	@echo   1. Copiar advent.bin a SD Card
	@echo   2. En el monitor:
	@echo      SD
	@echo      LOAD ADVENT.BIN 0400
	@echo      G 0400
	@echo ========================================

dirs:
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	@if not exist $(OUTPUT_DIR) mkdir $(OUTPUT_DIR)

$(OBJ): $(SRC)
	$(CA65) -t none -o $@ $<

$(TARGET): $(OBJ) $(CFG)
	$(LD65) -C $(CFG) -o $@ $(OBJ) -m $(MAP_FILE)

clean:
	@if exist $(BUILD_DIR)\*.o del $(BUILD_DIR)\*.o
	@if exist $(BUILD_DIR)\*.map del $(BUILD_DIR)\*.map
	@if exist $(OUTPUT_DIR)\*.bin del $(OUTPUT_DIR)\*.bin
	@echo Limpiado

info:
	@echo ========================================
	@echo Informacion del binario
	@echo ========================================
	@for %%I in ($(TARGET)) do @echo Tamano: %%~zI bytes
	@echo Carga en: $$0400
	@echo ========================================

.PHONY: all clean dirs info
