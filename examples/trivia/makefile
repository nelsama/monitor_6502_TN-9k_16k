CC65_PATH = D:/cc65
CA65 = $(CC65_PATH)/bin/ca65
LD65 = $(CC65_PATH)/bin/ld65

SRC_DIR = src
BUILD_DIR = build
OUTPUT_DIR = output
CONFIG_DIR = config

TARGET = $(OUTPUT_DIR)/trivia.bin
MAP_FILE = $(BUILD_DIR)/trivia.map
SRC = $(SRC_DIR)/main.s
OBJ = $(BUILD_DIR)/main.o
CFG = $(CONFIG_DIR)/programa.cfg

all: dirs $(TARGET)
	@echo ========================================
	@echo COMPILADO: $(TARGET)
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
