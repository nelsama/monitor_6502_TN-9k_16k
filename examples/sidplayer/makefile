# Makefile para SID Player - Monitor 6502
# Reproduce archivos .sid desde SD Card

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

# Librerías del proyecto principal
LIBS_DIR = ../../libs
MICROFS_DIR = $(LIBS_DIR)/microfs-6502-cc65
SDCARD_DIR = $(LIBS_DIR)/sdcard-spi-6502-cc65
SPI_DIR = $(LIBS_DIR)/spi-6502-cc65

# ============================================
# ARCHIVOS FUENTE
# ============================================
C_SOURCES = $(SRC_DIR)/main.c \
            $(MICROFS_DIR)/microfs.c \
            $(SDCARD_DIR)/sdcard.c

ASM_SOURCES = $(SRC_DIR)/startup.s \
              $(SRC_DIR)/sid_player.s \
              $(MICROFS_DIR)/microfs_asm.s \
              $(SDCARD_DIR)/sdcard_asm.s \
              $(SPI_DIR)/spi.s

# ============================================
# ARCHIVOS OBJETO
# ============================================
C_OBJECTS = $(BUILD_DIR)/main.o \
            $(BUILD_DIR)/microfs.o \
            $(BUILD_DIR)/sdcard.o

ASM_OBJECTS = $(BUILD_DIR)/startup.o \
              $(BUILD_DIR)/sid_player.o \
              $(BUILD_DIR)/microfs_asm.o \
              $(BUILD_DIR)/sdcard_asm.o \
              $(BUILD_DIR)/spi.o

OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

# ============================================
# CONFIG Y TARGET
# ============================================
CONFIG = $(CONFIG_DIR)/programa.cfg
TARGET = $(OUTPUT_DIR)/sidplay.bin

# ============================================
# FLAGS
# ============================================
CFLAGS = -t none -O --cpu 6502 -I $(SRC_DIR) -I $(MICROFS_DIR) -I $(SDCARD_DIR) -I $(SPI_DIR)
ASFLAGS = -t none --cpu 6502
LDFLAGS = -C $(CONFIG)

# ============================================
# REGLAS
# ============================================
all: dirs $(TARGET)
	@echo ========================================
	@echo COMPILADO: $(TARGET)
	@echo ========================================
	@echo Para usar:
	@echo   1. Copiar sidplay.bin a SD como SIDPLAY
	@echo   2. Copiar archivos .sid a la SD
	@echo   3. En el monitor:
	@echo      LOAD SIDPLAY
	@echo      R
	@echo   4. Introducir nombre del archivo .sid
	@echo ========================================

dirs:
	@if not exist "$(BUILD_DIR)" mkdir "$(BUILD_DIR)"
	@if not exist "$(OUTPUT_DIR)" mkdir "$(OUTPUT_DIR)"

# Compilar C
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(BUILD_DIR)/microfs.o: $(MICROFS_DIR)/microfs.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(BUILD_DIR)/sdcard.o: $(SDCARD_DIR)/sdcard.c
	$(CC) -c $(CFLAGS) -o $@ $<

# Ensamblar ASM
$(BUILD_DIR)/startup.o: $(SRC_DIR)/startup.s
	$(CA65) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/sid_player.o: $(SRC_DIR)/sid_player.s
	$(CA65) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/microfs_asm.o: $(MICROFS_DIR)/microfs_asm.s
	$(CA65) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/sdcard_asm.o: $(SDCARD_DIR)/sdcard_asm.s
	$(CA65) $(ASFLAGS) -o $@ $<

$(BUILD_DIR)/spi.o: $(SPI_DIR)/spi.s
	$(CA65) $(ASFLAGS) -o $@ $<

# Linkar
$(TARGET): $(OBJECTS)
	$(LD65) $(LDFLAGS) -o $@ $(OBJECTS) $(CC65_HOME)/lib/none.lib

clean:
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(OUTPUT_DIR)" rmdir /s /q "$(OUTPUT_DIR)"
	@echo Limpieza completada

.PHONY: all dirs clean
