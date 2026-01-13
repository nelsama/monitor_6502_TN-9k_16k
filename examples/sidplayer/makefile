# Makefile para SID Player - Monitor 6502
# Reproduce archivos .sid desde SD Card
# 
# NOTA: Usa ROM API - no incluye librerías SD/MicroFS
#       Requiere monitor con jump table en $BF00

# ============================================
# CONFIGURACIÓN DE CC65
# ============================================
CC65_HOME = D:\cc65
CC = cl65
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
# ARCHIVOS FUENTE
# Ya no necesita SD/MicroFS/SPI - usa ROM API
# ============================================
C_SOURCES = $(SRC_DIR)/main.c

ASM_SOURCES = $(SRC_DIR)/startup.s \
              $(SRC_DIR)/sid_player.s

# ============================================
# ARCHIVOS OBJETO
# ============================================
C_OBJECTS = $(BUILD_DIR)/main.o

ASM_OBJECTS = $(BUILD_DIR)/startup.o \
              $(BUILD_DIR)/sid_player.o

OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

# ============================================
# CONFIG Y TARGET
# ============================================
CONFIG = $(CONFIG_DIR)/programa.cfg
TARGET = $(OUTPUT_DIR)/sidplay.bin

# ============================================
# FLAGS
# ============================================
CFLAGS = -t none -O --cpu 6502 -I $(SRC_DIR)
ASFLAGS = -t none --cpu 6502
LDFLAGS = -C $(CONFIG)

# ============================================
# REGLAS
# ============================================
all: dirs $(TARGET)
	@echo ========================================
	@echo COMPILADO: $(TARGET)
	@echo Tamano: 
	@for %%I in ($(TARGET)) do @echo   %%~zI bytes
	@echo ========================================
	@echo Para usar:
	@echo   1. Copiar sidplay.bin a SD como SIDPLAY
	@echo   2. Copiar archivos .sid a la SD
	@echo   3. En el monitor:
	@echo      LOAD SIDPLAY 2700
	@echo      R 2700
	@echo   4. Introducir nombre del archivo .sid
	@echo ========================================

dirs:
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"

# Compilar C
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c
	$(CC) -c $(CFLAGS) -o $@ $<

# Ensamblar ASM
$(BUILD_DIR)/startup.o: $(SRC_DIR)/startup.s
	$(CA65) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/sid_player.o: $(SRC_DIR)/sid_player.s
	$(CA65) $(ASFLAGS) -o $@ $<

# Linkar
$(TARGET): $(OBJECTS)
	$(LD65) $(LDFLAGS) -o $@ $(OBJECTS) $(CC65_HOME)/lib/none.lib

clean:
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(OUTPUT_DIR)" rmdir /s /q "$(OUTPUT_DIR)"
	@echo Limpieza completada

.PHONY: all dirs clean
