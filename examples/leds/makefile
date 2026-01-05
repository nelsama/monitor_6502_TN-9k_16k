# ============================================================================
# Makefile - Plantilla para programas en ensamblador para Monitor 6502
# ============================================================================
# Uso:
#   make        - Compilar el programa
#   make clean  - Limpiar archivos generados
#   make info   - Ver tamaño del binario
#   make map    - Ver mapa de memoria
# ============================================================================

# Configuración CC65 - Ajustar ruta si es necesario
CC65_HOME = D:\cc65

# Herramientas
AS = $(CC65_HOME)\bin\ca65.exe
LD = $(CC65_HOME)\bin\ld65.exe

# Directorios
SRC_DIR = src
CONFIG_DIR = config
BUILD_DIR = build
OUTPUT_DIR = output

# Configuración del linker
LD_CONFIG = $(CONFIG_DIR)\programa.cfg

# Nombre del programa
PROGRAM_NAME = leds

# Archivos de salida
PROGRAM = $(OUTPUT_DIR)\$(PROGRAM_NAME).bin
MAP_FILE = $(OUTPUT_DIR)\$(PROGRAM_NAME).map

# Archivos fuente ensamblador
ASM_SOURCES = $(SRC_DIR)\main.s

# Archivos objeto
ASM_OBJECTS = $(BUILD_DIR)\main.o

# Flags del ensamblador
AS_FLAGS = -t none

# ============================================================================
# REGLAS PRINCIPALES
# ============================================================================

all: dirs $(PROGRAM)
	@echo.
	@echo ========================================
	@echo Programa generado: $(PROGRAM)
	@echo Mapa de memoria:   $(MAP_FILE)
	@echo ========================================
	@echo.
	@echo Para cargar en el monitor:
	@echo   1. Copiar $(PROGRAM_NAME).bin a la SD
	@echo   2. En el monitor: LOAD $(PROGRAM_NAME).BIN 0400
	@echo   3. Ejecutar: G 0400

# Crear directorios
dirs:
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	@if not exist $(OUTPUT_DIR) mkdir $(OUTPUT_DIR)

# Ensamblar archivo principal
$(BUILD_DIR)\main.o: $(SRC_DIR)\main.s
	$(AS) $(AS_FLAGS) -o $@ $<

# Enlazar el programa
$(PROGRAM): $(ASM_OBJECTS)
	$(LD) -C $(LD_CONFIG) -o $@ -m $(MAP_FILE) $(ASM_OBJECTS)

# ============================================================================
# LIMPIEZA
# ============================================================================

clean:
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
	@if exist $(OUTPUT_DIR) rmdir /s /q $(OUTPUT_DIR)
	@echo Limpieza completada

# ============================================================================
# UTILIDADES
# ============================================================================

# Ver tamaño del binario
info: $(PROGRAM)
	@echo.
	@echo Informacion del programa:
	@for %%I in ($(PROGRAM)) do @echo   Tamaño: %%~zI bytes
	@echo   Direccion de carga: $$0400

# Ver mapa de memoria
map: $(PROGRAM)
	@type $(MAP_FILE)

.PHONY: all dirs clean info map

.PHONY: all dirs clean info map
