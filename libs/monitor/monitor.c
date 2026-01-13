/**
 * MONITOR.C - Monitor/Debugger para 6502 via UART
 * 
 * Implementación de interfaz de comandos estilo Wozmon/Supermon
 */

#include "monitor.h"
#include "../uart-6502-cc65/uart.h"
#include "../sdcard-spi-6502-cc65/sdcard.h"
#include "../microfs-6502-cc65/microfs.h"
#include "../../src/xmodem.h"

/* Buffer de entrada */
static char input_buffer[MON_BUFFER_SIZE];
static uint8_t input_pos;

/* Última dirección usada (para comandos continuos) */
static uint16_t last_addr = 0x0200;

/* Estado SD Card */
static uint8_t sd_initialized = 0;
static uint8_t fs_mounted = 0;

/* Tabla de caracteres hex */
static const char hex_chars[] = "0123456789ABCDEF";

/* ============================================
 * FUNCIONES DE UTILIDAD - IMPRESIÓN
 * ============================================ */

void mon_newline(void) {
    uart_putc('\r');
    uart_putc('\n');
}

void mon_print_hex8(uint8_t val) {
    uart_putc(hex_chars[(val >> 4) & 0x0F]);
    uart_putc(hex_chars[val & 0x0F]);
}

void mon_print_hex16(uint16_t val) {
    mon_print_hex8((uint8_t)(val >> 8));
    mon_print_hex8((uint8_t)(val & 0xFF));
}

static void mon_print_space(void) {
    uart_putc(' ');
}

static void mon_prompt(void) {
    mon_newline();
    uart_putc('>');
}

static void mon_error(const char *msg) {
    uart_puts("ERR: ");
    uart_puts(msg);
    mon_newline();
}

static void mon_ok(void) {
    uart_puts("OK");
    mon_newline();
}

/* ============================================
 * FUNCIONES DE CONVERSIÓN
 * ============================================ */

/**
 * Convertir carácter hex a valor
 */
static uint8_t hex_char_to_val(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return 0xFF; /* Error */
}

/**
 * Verificar si es carácter hex válido
 */
static uint8_t is_hex_char(char c) {
    return (c >= '0' && c <= '9') ||
           (c >= 'A' && c <= 'F') ||
           (c >= 'a' && c <= 'f');
}

uint8_t mon_hex_to_u8(const char *str) {
    uint8_t result = 0;
    uint8_t i;
    
    for (i = 0; i < 2 && str[i] != '\0'; i++) {
        if (!is_hex_char(str[i])) break;
        result = (result << 4) | hex_char_to_val(str[i]);
    }
    return result;
}

uint16_t mon_hex_to_u16(const char *str) {
    uint16_t result = 0;
    uint8_t i;
    
    for (i = 0; i < 4 && str[i] != '\0'; i++) {
        if (!is_hex_char(str[i])) break;
        result = (result << 4) | hex_char_to_val(str[i]);
    }
    return result;
}

/**
 * Parsear siguiente token hex de la cadena
 * Retorna puntero al siguiente espacio o fin de cadena
 */
static const char* parse_hex_token(const char *str, uint16_t *value) {
    *value = 0;
    
    /* Saltar espacios */
    while (*str == ' ') str++;
    
    /* Parsear hex */
    while (is_hex_char(*str)) {
        *value = (*value << 4) | hex_char_to_val(*str);
        str++;
    }
    
    return str;
}

/* ============================================
 * FUNCIONES DE MEMORIA
 * ============================================ */

uint8_t mon_read_byte(uint16_t addr) {
    return *((volatile uint8_t *)addr);
}

void mon_write_byte(uint16_t addr, uint8_t value) {
    *((volatile uint8_t *)addr) = value;
}

void mon_dump(uint16_t addr, uint16_t len) {
    uint16_t i;
    uint8_t j;
    uint8_t data[16];
    uint16_t row_addr;
    
    for (i = 0; i < len; i += 16) {
        row_addr = addr + i;
        
        /* Imprimir dirección */
        mon_print_hex16(row_addr);
        uart_puts(": ");
        
        /* Leer y mostrar bytes hex */
        for (j = 0; j < 16 && (i + j) < len; j++) {
            data[j] = mon_read_byte(row_addr + j);
            mon_print_hex8(data[j]);
            mon_print_space();
        }
        
        /* Padding si línea incompleta */
        while (j < 16) {
            uart_puts("   ");
            j++;
        }
        
        /* Mostrar ASCII */
        uart_putc('|');
        for (j = 0; j < 16 && (i + j) < len; j++) {
            if (data[j] >= 0x20 && data[j] < 0x7F) {
                uart_putc(data[j]);
            } else {
                uart_putc('.');
            }
        }
        uart_putc('|');
        mon_newline();
    }
    
    last_addr = addr + len;
}

void mon_fill(uint16_t addr, uint16_t len, uint8_t value) {
    uint16_t i;
    for (i = 0; i < len; i++) {
        mon_write_byte(addr + i, value);
    }
}

/* ============================================
 * EJECUCIÓN DE CÓDIGO
 * ============================================ */

void mon_execute(uint16_t addr) {
    code_ptr code = (code_ptr)addr;
    
    uart_puts("Ejecutando en $");
    mon_print_hex16(addr);
    uart_puts("...");
    mon_newline();
    
    /* Saltar a la dirección */
    code();
    
    /* Si retorna, mostrar mensaje */
    mon_newline();
    uart_puts("Retorno de $");
    mon_print_hex16(addr);
    mon_newline();
}

/* ============================================
 * MODO CARGA DE BYTES
 * ============================================ */

/**
 * Modo carga: recibe bytes hex separados por espacio
 * Termina con '.' o línea vacía
 */
static void mon_load_mode(uint16_t addr) {
    char c;
    uint8_t byte_val;
    uint8_t nibble_count = 0;
    uint16_t bytes_loaded = 0;
    
    uart_puts("Modo carga en $");
    mon_print_hex16(addr);
    uart_puts(" (terminar con '.')");
    mon_newline();
    uart_putc(':');
    
    byte_val = 0;
    
    while (1) {
        c = uart_getc();
        
        /* Terminar con punto */
        if (c == '.') {
            break;
        }
        
        /* Enter - nueva línea de entrada */
        if (c == '\r' || c == '\n') {
            mon_newline();
            uart_putc(':');
            continue;
        }
        
        /* Espacio - separador */
        if (c == ' ') {
            uart_putc(' ');
            continue;
        }
        
        /* Procesar hex */
        if (is_hex_char(c)) {
            uart_putc(c); /* Echo */
            byte_val = (byte_val << 4) | hex_char_to_val(c);
            nibble_count++;
            
            if (nibble_count == 2) {
                /* Byte completo - escribir */
                mon_write_byte(addr, byte_val);
                addr++;
                bytes_loaded++;
                byte_val = 0;
                nibble_count = 0;
            }
        }
    }
    
    mon_newline();
    uart_puts("Cargados ");
    mon_print_hex16(bytes_loaded);
    uart_puts(" bytes");
    mon_newline();
    
    last_addr = addr;
}

/* ============================================
 * DESENSAMBLADOR BÁSICO
 * ============================================ */

/* Tabla simplificada de mnemonics (solo instrucciones comunes) */
static const char* get_mnemonic(uint8_t opcode) {
    switch (opcode) {
        case 0x00: return "BRK";
        case 0x20: return "JSR";
        case 0x40: return "RTI";
        case 0x60: return "RTS";
        case 0x4C: return "JMP";
        case 0x6C: return "JMP()";
        case 0xA9: return "LDA#";
        case 0xA5: return "LDAzp";
        case 0xAD: return "LDAab";
        case 0xA2: return "LDX#";
        case 0xA0: return "LDY#";
        case 0x85: return "STAzp";
        case 0x8D: return "STAab";
        case 0x86: return "STXzp";
        case 0x84: return "STYzp";
        case 0xE8: return "INX";
        case 0xC8: return "INY";
        case 0xCA: return "DEX";
        case 0x88: return "DEY";
        case 0x18: return "CLC";
        case 0x38: return "SEC";
        case 0xD8: return "CLD";
        case 0xF8: return "SED";
        case 0x58: return "CLI";
        case 0x78: return "SEI";
        case 0xEA: return "NOP";
        case 0xAA: return "TAX";
        case 0xA8: return "TAY";
        case 0x8A: return "TXA";
        case 0x98: return "TYA";
        case 0x9A: return "TXS";
        case 0xBA: return "TSX";
        case 0x48: return "PHA";
        case 0x68: return "PLA";
        case 0x08: return "PHP";
        case 0x28: return "PLP";
        case 0x69: return "ADC#";
        case 0xE9: return "SBC#";
        case 0xC9: return "CMP#";
        case 0xE0: return "CPX#";
        case 0xC0: return "CPY#";
        case 0x29: return "AND#";
        case 0x09: return "ORA#";
        case 0x49: return "EOR#";
        case 0xD0: return "BNE";
        case 0xF0: return "BEQ";
        case 0x10: return "BPL";
        case 0x30: return "BMI";
        case 0x90: return "BCC";
        case 0xB0: return "BCS";
        case 0x50: return "BVC";
        case 0x70: return "BVS";
        default:   return "???";
    }
}

/* Bytes por instrucción (simplificado) */
static uint8_t get_instruction_len(uint8_t opcode) {
    /* Implied/Accumulator - 1 byte */
    if (opcode == 0x00 || opcode == 0x40 || opcode == 0x60 ||
        opcode == 0xE8 || opcode == 0xC8 || opcode == 0xCA ||
        opcode == 0x88 || opcode == 0x18 || opcode == 0x38 ||
        opcode == 0xD8 || opcode == 0xF8 || opcode == 0x58 ||
        opcode == 0x78 || opcode == 0xEA || opcode == 0xAA ||
        opcode == 0xA8 || opcode == 0x8A || opcode == 0x98 ||
        opcode == 0x9A || opcode == 0xBA || opcode == 0x48 ||
        opcode == 0x68 || opcode == 0x08 || opcode == 0x28) {
        return 1;
    }
    
    /* Immediate, Zero Page, Relative - 2 bytes */
    if ((opcode & 0x0F) == 0x09 || /* Immediate */
        (opcode & 0x0F) == 0x05 || /* Zero Page */
        (opcode & 0x0F) == 0x06 || /* Zero Page */
        (opcode & 0x1F) == 0x10 || /* Branches */
        opcode == 0xA2 || opcode == 0xA0 ||
        opcode == 0xE0 || opcode == 0xC0) {
        return 2;
    }
    
    /* Absolute, Indirect - 3 bytes */
    if (opcode == 0x20 || opcode == 0x4C || opcode == 0x6C ||
        (opcode & 0x0F) == 0x0D || /* Absolute */
        (opcode & 0x0F) == 0x0E) {
        return 3;
    }
    
    /* Por defecto asumir 2 bytes */
    return 2;
}

static void mon_disassemble(uint16_t addr, uint8_t lines) {
    uint8_t i, j, len;
    uint8_t opcode;
    uint8_t bytes[3];
    
    for (i = 0; i < lines; i++) {
        opcode = mon_read_byte(addr);
        len = get_instruction_len(opcode);
        
        /* Leer bytes de la instrucción */
        for (j = 0; j < len; j++) {
            bytes[j] = mon_read_byte(addr + j);
        }
        
        /* Imprimir dirección */
        mon_print_hex16(addr);
        uart_puts("  ");
        
        /* Imprimir bytes hex */
        for (j = 0; j < 3; j++) {
            if (j < len) {
                mon_print_hex8(bytes[j]);
            } else {
                uart_puts("  ");
            }
            mon_print_space();
        }
        
        /* Imprimir mnemonic */
        uart_puts(get_mnemonic(opcode));
        
        /* Imprimir operando si hay */
        if (len == 2) {
            uart_puts(" $");
            mon_print_hex8(bytes[1]);
        } else if (len == 3) {
            uart_puts(" $");
            mon_print_hex8(bytes[2]);
            mon_print_hex8(bytes[1]);
        }
        
        mon_newline();
        addr += len;
    }
    
    last_addr = addr;
}

/* ============================================
 * ANÁLISIS DE MEMORIA RAM
 * ============================================ */

/* Constantes del mapa de memoria */
#define RAM_START       0x0100
#define RAM_END         0x3DFF
#define ZP_START        0x0002
#define ZP_END          0x00FF
#define STACK_START     0x3E00
#define STACK_END       0x3FFF
#define ROM_START       0x8000
#define ROM_END         0x9FFF
#define IO_START        0xC000
#define IO_END          0xC0FF

/**
 * Imprimir número decimal (hasta 65535)
 */
static void mon_print_dec(uint16_t val) {
    char buf[6];
    uint8_t i = 0;
    
    if (val == 0) {
        uart_putc('0');
        return;
    }
    
    while (val > 0) {
        buf[i++] = '0' + (val % 10);
        val /= 10;
    }
    
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

/**
 * Mostrar información del sistema (mapa de memoria)
 */
static void mon_info(void) {
    mon_newline();
    uart_puts("=== MAPA DE MEMORIA ===");
    mon_newline();
    mon_newline();
    
    uart_puts("Zero Page:  $0002-$00FF (");
    mon_print_dec(ZP_END - ZP_START + 1);
    uart_puts(" bytes)");
    mon_newline();
    
    uart_puts("RAM:        $0100-$3DFF (");
    mon_print_dec(RAM_END - RAM_START + 1);
    uart_puts(" bytes)");
    mon_newline();
    
    uart_puts("Stack:      $3E00-$3FFF (");
    mon_print_dec(STACK_END - STACK_START + 1);
    uart_puts(" bytes)");
    mon_newline();
    
    uart_puts("ROM:        $8000-$9FFF (~8 KB)");
    mon_newline();
    
    uart_puts("I/O:        $C000-$C0FF");
    mon_newline();
    mon_newline();
    
    uart_puts("RAM libre para programas:");
    mon_newline();
    uart_puts("  $0200-$3DFF (");
    mon_print_dec(0x3DFF - 0x0200 + 1);
    uart_puts(" bytes)");
    mon_newline();
}

/**
 * Escanear rango de memoria y contar bytes "libres" (00 o FF)
 * Muestra estadísticas y bloques libres
 */
/* mon_scan removed to save space */

/**
 * Prueba de RAM: escribir y leer para verificar que funciona
 * Usa un test simple: escribe valor, lee, verifica
 */
/* mon_test_ram removed to save space */

/**
 * Vista rápida de uso de memoria (mapa visual)
 */
/* mon_memmap removed to save space */

/* ============================================
 * FUNCIONES SD CARD
 * ============================================ */

/**
 * Inicializar SD Card y montar filesystem
 */
static void mon_sd_init(void) {
    uint8_t r;
    
    uart_puts("Inicializando SD Card...");
    mon_newline();
    
    r = sd_init();
    if (r != SD_OK) {
        uart_puts("  Error SD: ");
        mon_print_hex8(r);
        mon_newline();
        sd_initialized = 0;
        fs_mounted = 0;
        return;
    }
    
    sd_initialized = 1;
    uart_puts("  SD OK, tipo: ");
    uart_putc(sd_get_type() == 2 ? 'H' : 'S');
    uart_putc('D');
    mon_newline();
    
    /* Montar filesystem */
    uart_puts("Montando MicroFS...");
    mon_newline();
    
    r = mfs_mount();
    if (r == MFS_ERR_NOFS) {
        uart_puts("  Sin FS. Formatear? (S/N): ");
        if (uart_getc() == 'S' || uart_getc() == 's') {
            mon_newline();
            uart_puts("  Formateando...");
            r = mfs_format();
            if (r == MFS_OK) {
                uart_puts("OK");
                mon_newline();
                r = mfs_mount();
            }
        } else {
            mon_newline();
            return;
        }
    }
    
    if (r == MFS_OK) {
        fs_mounted = 1;
        uart_puts("  FS montado OK");
    } else {
        uart_puts("  Error FS: ");
        mon_print_hex8(r);
    }
    mon_newline();
}

/**
 * Listar archivos en SD
 */
static void mon_sd_list(void) {
    mfs_fileinfo_t info;
    uint8_t i;
    uint8_t count = 0;
    
    if (!fs_mounted) {
        uart_puts("SD no montada. Use SD primero");
        mon_newline();
        return;
    }
    
    uart_puts("Archivos:");
    mon_newline();
    
    for (i = 0; i < MFS_MAX_FILES; i++) {
        if (mfs_list(i, &info) == MFS_OK) {
            uart_puts("  ");
            uart_puts(info.name);
            uart_puts("  ");
            mon_print_dec(info.size);
            uart_puts(" bytes");
            mon_newline();
            count++;
        }
    }
    
    if (count == 0) {
        uart_puts("  (vacio)");
        mon_newline();
    }
    
    uart_puts("Total: ");
    mon_print_dec(count);
    uart_puts("/16 archivos");
    mon_newline();
}

/**
 * Guardar memoria a archivo SD
 * SAVE nombre addr len
 */
static void mon_sd_save(const char *name, uint16_t addr, uint16_t len) {
    uint8_t r;
    uint16_t written = 0;
    uint16_t chunk;
    uint8_t buf[64];
    uint16_t i;
    
    if (!fs_mounted) {
        uart_puts("SD no montada");
        mon_newline();
        return;
    }
    
    if (len == 0 || len > 0x8000) {
        uart_puts("Len invalido (1-8000h)");
        mon_newline();
        return;
    }
    
    /* Eliminar si existe */
    mfs_delete(name);
    
    /* Crear archivo */
    r = mfs_create(name, len);
    if (r != MFS_OK) {
        uart_puts("Error crear: ");
        mon_print_hex8(r);
        mon_newline();
        return;
    }
    
    uart_puts("Guardando $");
    mon_print_hex16(addr);
    uart_puts("-$");
    mon_print_hex16(addr + len - 1);
    uart_puts(" -> ");
    uart_puts(name);
    mon_newline();
    
    /* Escribir en chunks */
    while (written < len) {
        chunk = len - written;
        if (chunk > 64) chunk = 64;
        
        /* Leer memoria */
        for (i = 0; i < chunk; i++) {
            buf[i] = mon_read_byte(addr + written + i);
        }
        
        /* Escribir a archivo */
        mfs_write(buf, chunk);
        written += chunk;
        
        /* Mostrar progreso cada 1KB */
        if ((written & 0x3FF) == 0) {
            uart_putc('.');
        }
    }
    
    mfs_close();
    
    mon_newline();
    uart_puts("OK: ");
    mon_print_dec(written);
    uart_puts(" bytes");
    mon_newline();
}

/**
 * Cargar archivo SD a memoria
 * LOAD nombre addr
 */
static void mon_sd_load(const char *name, uint16_t addr) {
    uint8_t r;
    uint16_t loaded = 0;
    uint16_t chunk;
    uint8_t buf[64];
    uint16_t i;
    uint16_t size;
    
    if (!fs_mounted) {
        uart_puts("SD no montada");
        mon_newline();
        return;
    }
    
    /* Abrir archivo */
    r = mfs_open(name);
    if (r != MFS_OK) {
        uart_puts("No encontrado: ");
        uart_puts(name);
        mon_newline();
        return;
    }
    
    /* Obtener tamaño del archivo abierto */
    size = mfs_get_size();
    
    uart_puts("Cargando ");
    uart_puts(name);
    uart_puts(" (");
    mon_print_dec(size);
    uart_puts(" bytes) -> $");
    mon_print_hex16(addr);
    mon_newline();
    
    /* Leer en chunks */
    while (loaded < size) {
        chunk = mfs_read(buf, 64);
        if (chunk == 0) break;
        
        /* Escribir a memoria */
        for (i = 0; i < chunk; i++) {
            mon_write_byte(addr + loaded + i, buf[i]);
        }
        
        loaded += chunk;
        
        /* Mostrar progreso */
        if ((loaded & 0x3FF) == 0) {
            uart_putc('.');
        }
    }
    
    mfs_close();
    
    mon_newline();
    uart_puts("OK: ");
    mon_print_dec(loaded);
    uart_puts(" bytes en $");
    mon_print_hex16(addr);
    uart_puts("-$");
    mon_print_hex16(addr + loaded - 1);
    mon_newline();
    
    last_addr = addr;
}

/**
 * Eliminar archivo
 */
static void mon_sd_delete(const char *name) {
    uint8_t r;
    
    if (!fs_mounted) {
        uart_puts("SD no montada");
        mon_newline();
        return;
    }
    
    r = mfs_delete(name);
    if (r == MFS_OK) {
        uart_puts("Eliminado: ");
        uart_puts(name);
    } else {
        uart_puts("Error: ");
        mon_print_hex8(r);
    }
    mon_newline();
}

/**
 * Mostrar contenido de archivo (hexdump)
 */
static void mon_sd_cat(const char *name) {
    uint8_t r;
    uint8_t buf[16];
    uint16_t total = 0;
    uint16_t n;
    uint8_t i;
    
    if (!fs_mounted) {
        uart_puts("SD no montada");
        mon_newline();
        return;
    }
    
    r = mfs_open(name);
    if (r != MFS_OK) {
        uart_puts("No encontrado");
        mon_newline();
        return;
    }
    
    uart_puts("=== ");
    uart_puts(name);
    uart_puts(" ===");
    mon_newline();
    
    while (1) {
        n = mfs_read(buf, 16);
        if (n == 0) break;
        
        /* Dirección */
        mon_print_hex16(total);
        uart_puts(": ");
        
        /* Hex */
        for (i = 0; i < n; i++) {
            mon_print_hex8(buf[i]);
            uart_putc(' ');
        }
        
        /* Padding */
        for (; i < 16; i++) {
            uart_puts("   ");
        }
        
        /* ASCII */
        uart_putc('|');
        for (i = 0; i < n; i++) {
            if (buf[i] >= 0x20 && buf[i] < 0x7F) {
                uart_putc(buf[i]);
            } else {
                uart_putc('.');
            }
        }
        uart_putc('|');
        mon_newline();
        
        total += n;
        
        /* Limitar a 256 bytes en pantalla */
        if (total >= 256) {
            uart_puts("...(");
            mon_print_dec(total);
            uart_puts(" bytes mostrados)");
            mon_newline();
            break;
        }
    }
    
    mfs_close();
}

/* ============================================
 * AYUDA
 * ============================================ */

/* Prototipo adelantado */
static uint8_t cmd_match(const char *cmd, const char *pattern);

static void mon_help(void) {
    mon_newline();
    uart_puts("=== MONITOR 6502 ===\r\n");
    uart_puts("Valores HEX. H cmd=ayuda detallada\r\n");
    uart_puts("RD addr    Leer byte\r\n");
    uart_puts("W addr val Escribir\r\n");
    uart_puts("D addr len Dump hex\r\n");
    uart_puts("L addr     Cargar hex(.=fin)\r\n");
    uart_puts("R [addr]   Run (def $0800)\r\n");
    uart_puts("F addr l v Fill\r\n");
    uart_puts("M addr [n] Desensamblar\r\n");
    uart_puts("XRECV [addr] XMODEM (def $0800)\r\n");
    uart_puts("I          Info memoria\r\n");
    uart_puts("--- SD ---\r\n");
    uart_puts("SD/LS/SDFORMAT SAVE/LOAD/DEL/CAT\r\n");
    uart_puts("H/?/Q Ayuda/Salir\r\n");
    uart_puts("RAM prog: $0800-$3DFF\r\n");
}

/* Ayuda detallada por comando (compacta para ahorrar ROM) */
static void mon_help_cmd(char cmd) {
    /* Convertir a mayúscula */
    if (cmd >= 'a' && cmd <= 'z') cmd -= 32;
    
    mon_newline();
    
    switch (cmd) {
        case 'R':
            uart_puts("R [addr] - Run/ejecutar codigo\r\n");
            uart_puts("addr default=$0800\r\n");
            uart_puts("Debe terminar con RTS ($60)\r\n");
            uart_puts("Ej: R, R 0800, R 1000\r\n");
            uart_puts("RD addr - Leer byte\r\n");
            uart_puts("Ej: RD 0200, RD C000\r\n");
            break;
        case 'W':
            uart_puts("W addr val - Escribir byte\r\n");
            uart_puts("Ej: W 0200 FF, W C001 3F\r\n");
            break;
        case 'D':
            uart_puts("D addr [len] - Dump hex+ASCII\r\n");
            uart_puts("len default=64. Ej: D 0200 100\r\n");
            break;
        case 'L':
            uart_puts("L addr - Cargar hex interactivo\r\n");
            uart_puts("Escribe bytes, '.' termina\r\n");
            uart_puts("Ej: L 0200 -> A9 01 8D 01 C0 60 .\r\n");
            break;
        case 'F':
            uart_puts("F addr len val - Fill memoria\r\n");
            uart_puts("Ej: F 0200 100 00, F 0200 10 EA\r\n");
            break;
        case 'M':
            uart_puts("M addr [n] - Desensamblar\r\n");
            uart_puts("n=instrucciones (def 16)\r\n");
            uart_puts("Ej: M 0200, M 8000 20\r\n");
            break;
        case 'I':
            uart_puts("I - Info mapa memoria\r\n");
            uart_puts("Muestra rangos: ZP,Stack,RAM,I/O,ROM\r\n");
            break;
        case 'Q':
            uart_puts("Q - Salir del monitor\r\n");
            break;
        default:
            uart_puts("Cmd '");
            uart_putc(cmd);
            uart_puts("' no existe. Usa H\r\n");
            break;
    }
}

/* Ayuda para comandos SD */
static void mon_help_sd(const char *cmd) {
    mon_newline();
    
    if (cmd_match(cmd, "SD")) {
        uart_puts("SD - Inicializar SD Card\r\n");
        uart_puts("Ejecutar antes de otros cmd SD\r\n");
    }
    else if (cmd_match(cmd, "LS")) {
        uart_puts("LS - Listar archivos SD\r\n");
        uart_puts("Muestra nombre y tamano\r\n");
    }
    else if (cmd_match(cmd, "SAVE")) {
        uart_puts("SAVE file addr len\r\n");
        uart_puts("Guarda memoria a SD\r\n");
        uart_puts("Ej: SAVE PROG.BIN 0200 100\r\n");
    }
    else if (cmd_match(cmd, "LOAD")) {
        uart_puts("LOAD file [addr]\r\n");
        uart_puts("Carga archivo a memoria\r\n");
        uart_puts("addr default=$0800\r\n");
        uart_puts("Ej: LOAD PROG.BIN, LOAD P.BIN 1000\r\n");
    }
    else if (cmd_match(cmd, "DEL")) {
        uart_puts("DEL file - Eliminar archivo\r\n");
        uart_puts("Ej: DEL VIEJO.BIN\r\n");
    }
    else if (cmd_match(cmd, "CAT")) {
        uart_puts("CAT file - Ver contenido hex\r\n");
        uart_puts("Ej: CAT PROG.BIN\r\n");
    }
    else if (cmd_match(cmd, "SDFORMAT")) {
        uart_puts("SDFORMAT - Formatear SD\r\n");
        uart_puts("BORRA todos los archivos!\r\n");
    }
    else if (cmd_match(cmd, "XRECV")) {
        uart_puts("XRECV [addr] - Recibir XMODEM\r\n");
        uart_puts("addr default=$0800\r\n");
        uart_puts("Ej: XRECV, XRECV 1000\r\n");
    }
    else {
        uart_puts("Cmds SD: SD,LS,SAVE,LOAD,DEL,CAT,SDFORMAT\r\n");
    }
}

/* ============================================
 * PROCESAMIENTO DE COMANDOS
 * ============================================ */

/* Función auxiliar para comparar comandos */
static uint8_t cmd_match(const char *cmd, const char *pattern) {
    while (*pattern) {
        char c = *cmd;
        if (c >= 'a' && c <= 'z') c -= 32;
        if (c != *pattern) return 0;
        cmd++;
        pattern++;
    }
    /* Verificar que termina en espacio o fin */
    return (*cmd == ' ' || *cmd == '\0');
}

/* Función auxiliar para obtener nombre de archivo (convierte a mayúsculas) */
static const char* parse_filename(const char *str, char *name, uint8_t maxlen) {
    uint8_t i = 0;
    char c;
    
    /* Saltar espacios */
    while (*str == ' ') str++;
    
    /* Copiar hasta espacio o fin, convertir a mayúsculas */
    while (*str && *str != ' ' && i < maxlen - 1) {
        c = *str++;
        if (c >= 'a' && c <= 'z') c -= 32;  /* A mayúsculas */
        name[i++] = c;
    }
    name[i] = '\0';
    
    return str;
}

uint8_t monitor_process_cmd(char *cmd) {
    char command;
    const char *ptr;
    uint16_t addr, len, val;
    char filename[13];  /* 8.3 + null */
    
    /* Saltar espacios iniciales */
    while (*cmd == ' ') cmd++;
    
    /* Comando vacío */
    if (*cmd == '\0') return MON_OK;
    
    /* Comandos multi-caracter primero */
    if (cmd_match(cmd, "SAVE")) {
        ptr = cmd + 4;
        ptr = parse_filename(ptr, filename, 13);
        ptr = parse_hex_token(ptr, &addr);
        ptr = parse_hex_token(ptr, &len);
        if (filename[0] && addr && len) {
            mon_sd_save(filename, addr, len);
        } else {
            mon_error("Uso: SAVE nombre addr len");
        }
        return MON_OK;
    }
    
    if (cmd_match(cmd, "LOAD")) {
        ptr = cmd + 4;
        ptr = parse_filename(ptr, filename, 13);
        ptr = parse_hex_token(ptr, &addr);
        if (addr == 0) addr = 0x0800; /* Default address */
        if (filename[0]) {
            mon_sd_load(filename, addr);
        } else {
            mon_error("Uso: LOAD nombre [addr]");
        }
        return MON_OK;
    }
    
    if (cmd_match(cmd, "DEL")) {
        ptr = cmd + 3;
        ptr = parse_filename(ptr, filename, 13);
        if (filename[0]) {
            mon_sd_delete(filename);
        } else {
            mon_error("Uso: DEL nombre");
        }
        return MON_OK;
    }
    
    if (cmd_match(cmd, "CAT")) {
        ptr = cmd + 3;
        ptr = parse_filename(ptr, filename, 13);
        if (filename[0]) {
            mon_sd_cat(filename);
        } else {
            mon_error("Uso: CAT nombre");
        }
        return MON_OK;
    }
    
    if (cmd_match(cmd, "LS")) {
        mon_sd_list();
        return MON_OK;
    }
    
    if (cmd_match(cmd, "SD")) {
        mon_sd_init();
        return MON_OK;
    }
    
    if (cmd_match(cmd, "SDFORMAT")) {
        uint8_t r;
        uart_puts("Formateando SD...");
        mon_newline();
        r = mfs_format();
        if (r == MFS_OK) {
            uart_puts("OK: SD formateada");
        } else {
            uart_puts("Error: ");
            mon_print_hex8(r);
        }
        mon_newline();
        return MON_OK;
    }
    
    if (cmd_match(cmd, "XRECV")) {
        int bytes;
        
        ptr = cmd + 5;
        ptr = parse_hex_token(ptr, &addr);
        if (addr == 0) addr = 0x0800; /* Default address (después de BSS) */
        
        uart_puts("Listo para XMODEM en $");
        mon_print_hex16(addr);
        mon_newline();
        uart_puts("Inicie transferencia...");
        mon_newline();
        
        bytes = xmodem_receive(addr);
        
        /* Pequeña pausa y limpiar buffer UART */
        { unsigned int d; for(d=0; d<30000; d++); }
        while(uart_rx_ready()) uart_getc();
        
        if (bytes > 0) {
            mon_newline();
            uart_puts("OK: ");
            mon_print_dec((unsigned int)bytes);
            uart_puts(" bytes en $");
            mon_print_hex16(addr);
            uart_puts("-$");
            mon_print_hex16(addr + (unsigned int)bytes - 1);
            mon_newline();
        } else {
            mon_newline();
            uart_puts("Error XMODEM: ");
            mon_print_hex8((unsigned char)(-bytes));
            mon_newline();
        }
        return MON_OK;
    }
    
    /* Obtener comando (primer carácter) */
    command = *cmd;
    if (command >= 'a' && command <= 'z') {
        command -= 32; /* Convertir a mayúscula */
    }
    
    ptr = cmd + 1;
    
    switch (command) {
        case 'R': /* Read byte - ahora es RD */
            /* R sin addr = Run $0800 */
            if (*ptr == ' ' || *ptr == '\0') {
                /* Solo R = ejecutar */
                parse_hex_token(ptr, &addr);
                if (addr == 0) addr = 0x0800;
                mon_execute(addr);
            } else if ((*ptr == 'D' || *ptr == 'd') && (*(ptr+1) == ' ' || *(ptr+1) == '\0')) {
                /* RD = read byte */
                ptr++;
                ptr = parse_hex_token(ptr, &addr);
                if (addr == 0 && ptr == cmd + 2) {
                    addr = last_addr;
                }
                uart_putc('$');
                mon_print_hex16(addr);
                uart_puts(" = $");
                mon_print_hex8(mon_read_byte(addr));
                mon_newline();
                last_addr = addr + 1;
            } else {
                /* R addr = ejecutar en addr */
                ptr = parse_hex_token(ptr, &addr);
                if (addr == 0) addr = 0x0800;
                mon_execute(addr);
            }
            break;
            
        case 'W': /* Write byte */
            ptr = parse_hex_token(ptr, &addr);
            ptr = parse_hex_token(ptr, &val);
            mon_write_byte(addr, (uint8_t)val);
            uart_putc('$');
            mon_print_hex16(addr);
            uart_puts(" <- $");
            mon_print_hex8((uint8_t)val);
            mon_newline();
            last_addr = addr + 1;
            break;
            
        case 'D': /* Dump */
            ptr = parse_hex_token(ptr, &addr);
            ptr = parse_hex_token(ptr, &len);
            if (len == 0) len = 64; /* Default 64 bytes */
            mon_dump(addr, len);
            break;
            
        case 'L': /* Load mode */
            ptr = parse_hex_token(ptr, &addr);
            if (addr == 0) addr = last_addr;
            mon_load_mode(addr);
            break;
            
        case 'F': /* Fill */
            ptr = parse_hex_token(ptr, &addr);
            ptr = parse_hex_token(ptr, &len);
            ptr = parse_hex_token(ptr, &val);
            mon_fill(addr, len, (uint8_t)val);
            uart_puts("Filled $");
            mon_print_hex16(addr);
            uart_puts("-$");
            mon_print_hex16(addr + len - 1);
            uart_puts(" con $");
            mon_print_hex8((uint8_t)val);
            mon_newline();
            break;
            
        case 'M': /* Memory/Disassemble */
            ptr = parse_hex_token(ptr, &addr);
            if (addr == 0) addr = last_addr;
            ptr = parse_hex_token(ptr, &len);
            if (len == 0) len = 16;
            if (len > 255) {
                uart_puts("Max 255 (FF) lineas");
                mon_newline();
                len = 255;
            }
            mon_disassemble(addr, (uint8_t)len);
            break;
            
        case 'I': /* Info - Mapa de memoria */
            mon_info();
            break;
            
        case 'S':
        case 'T':
        case 'V':
            uart_puts("Cmd deshabilitado p/ XMODEM\r\n");
            break;
            
        case 'Q': /* Quit */
            uart_puts("Saliendo del monitor...");
            mon_newline();
            return MON_EXIT;
            
        case 'H':
        case '?':
            /* Saltar espacios después de H */
            while (*ptr == ' ') ptr++;
            
            if (*ptr == '\0') {
                /* H sin argumentos: ayuda general */
                mon_help();
            } else {
                /* H con argumento: ayuda específica */
                /* Verificar si es comando SD (multi-caracter) */
                if (cmd_match(ptr, "SD") || cmd_match(ptr, "LS") ||
                    cmd_match(ptr, "SAVE") || cmd_match(ptr, "LOAD") ||
                    cmd_match(ptr, "DEL") || cmd_match(ptr, "CAT")) {
                    mon_help_sd(ptr);
                } else {
                    /* Comando de un caracter */
                    mon_help_cmd(*ptr);
                }
            }
            break;
            
        default:
            mon_error("Comando desconocido. H=ayuda");
            break;
    }
    
    return MON_OK;
}

/* ============================================
 * ENTRADA DE LÍNEA
 * ============================================ */

static void mon_read_line(void) {
    char c;
    input_pos = 0;
    
    while (1) {
        c = uart_getc();
        
        /* Enter - fin de línea */
        if (c == '\r' || c == '\n') {
            input_buffer[input_pos] = '\0';
            mon_newline();
            return;
        }
        
        /* Backspace */
        if (c == 0x08 || c == 0x7F) {
            if (input_pos > 0) {
                input_pos--;
                uart_putc(0x08); /* Cursor atrás */
                uart_putc(' ');  /* Borrar carácter */
                uart_putc(0x08); /* Cursor atrás */
            }
            continue;
        }
        
        /* Escape - cancelar línea */
        if (c == 0x1B) {
            input_pos = 0;
            input_buffer[0] = '\0';
            uart_puts(" [ESC]");
            mon_newline();
            return;
        }
        
        /* Carácter normal */
        if (input_pos < MON_BUFFER_SIZE - 1 && c >= 0x20 && c < 0x7F) {
            input_buffer[input_pos++] = c;
            uart_putc(c); /* Echo */
        }
    }
}

/* ============================================
 * FUNCIONES PRINCIPALES
 * ============================================ */

void monitor_init(void) {
    input_pos = 0;
    last_addr = 0x0200;
}

void monitor_run(void) {
    uint8_t result;
    
    mon_newline();
    uart_puts("================================");
    mon_newline();
    uart_puts("  MONITOR 6502 v2.2.0 + SD");
    mon_newline();
    uart_puts("  Tang Nano 9K @ 3.375 MHz");
    mon_newline();
    uart_puts("================================");
    mon_newline();
    uart_puts("Escribe H para ayuda, SD para SD Card");
    
    while (1) {
        mon_prompt();
        mon_read_line();
        
        result = monitor_process_cmd(input_buffer);
        
        if (result == MON_EXIT) {
            break;
        }
    }
}
