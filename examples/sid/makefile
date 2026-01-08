# Makefile para ejemplo SID - Monitor 6502
# Genera melodía polifónica con el chip SID

# ============================================
# CONFIGURACIÓN DE CC65
# ============================================
CC65_HOME = D:\cc65
CA65 = ca65
LD65 = ld65

# ============================================
# DIRECTORIOS
# ============================================
SRC_DIR = src
BUILD_DIR = build
OUTPUT_DIR = output
CONFIG_DIR = config

# ============================================
# ARCHIVOS
# ============================================
SRC = $(SRC_DIR)/main.s
OBJ = $(BUILD_DIR)/main.o
CONFIG = $(CONFIG_DIR)/programa.cfg
TARGET = $(OUTPUT_DIR)/sid.bin

# ============================================
# REGLAS
# ============================================
all: dirs $(TARGET)
	@echo ========================================
	@echo COMPILADO: $(TARGET)
	@echo ========================================
	@echo Para usar:
	@echo   En el monitor:
	@echo      LOAD SID
	@echo      G 0800
	@echo   O via XMODEM:
	@echo      XRECV 0800
	@echo      G 0800
	@echo ========================================

dirs:
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"

$(OBJ): $(SRC)
	$(CA65) -t none -o $@ $<

$(TARGET): $(OBJ)
	$(LD65) -C $(CONFIG) -o $@ $< -m $(BUILD_DIR)/sid.map

clean:
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(OUTPUT_DIR)\*.bin" del /q "$(OUTPUT_DIR)\*.bin"
	@if exist "$(OUTPUT_DIR)\*.map" del /q "$(OUTPUT_DIR)\*.map"

info:
	@echo ========================================
	@echo Informacion del binario
	@echo ========================================
	@for %%f in ($(TARGET)) do @echo Tamano: %%~zf bytes
	@echo Carga en: $$0800
	@echo ========================================

map:
	@if exist "$(BUILD_DIR)\sid.map" type "$(BUILD_DIR)\sid.map"

.PHONY: all dirs clean info map
