/**
 * ============================================================================
 * SID PLAYER - Reproductor de archivos .sid para Monitor 6502
 * ============================================================================
 * Carga archivos .sid desde SD Card y los reproduce usando el chip SID
 * Compatible con formato PSID v1/v2 (la mayoría de SIDs clásicos)
 * 
 * NOTA: Usa ROM API - requiere monitor con jump table en $BF00
 *       No incluye librerías SD/MicroFS, las llama desde ROM
 * 
 * Controles:
 *   ESPACIO  - Pausa/Continuar
 *   N        - Siguiente canción
 *   P        - Canción anterior  
 *   Q        - Salir al monitor
 *   V        - Cambiar modo VU meter (Max/3ch/Off)
 *   1-9      - Ir a canción específica
 *
 * Uso: 
 *   LOAD SIDPLAY 1000
 *   R 1000
 *   (luego ingresa nombre del archivo)
 * ============================================================================
 */

#include <stdint.h>
#include <string.h>
#include "../../../include/romapi.h"

/* ============================================================================
 * HARDWARE
 * ============================================================================ */
#define LEDS            (*(volatile uint8_t *)0xC001)

/* Timer - 32-bit microsecond counter */
#define TIMER_USEC_0    (*(volatile uint8_t *)0xC038)
#define TIMER_USEC_1    (*(volatile uint8_t *)0xC039)
#define TIMER_USEC_2    (*(volatile uint8_t *)0xC03A)
#define TIMER_USEC_3    (*(volatile uint8_t *)0xC03B)
#define TIMER_LATCH     (*(volatile uint8_t *)0xC03C)
#define LATCH_USEC      0x02

/* SID Base */
#define SID_BASE        0xD400
#define SID_ENV3        (*(volatile uint8_t *)0xD41C)  /* Envelope voz 3 (SID original) */
#define SID_ENV1        (*(volatile uint8_t *)0xD41D)  /* Envelope voz 1 (extendido) */
#define SID_ENV2        (*(volatile uint8_t *)0xD41E)  /* Envelope voz 2 (extendido) */
#define SID_ENV_MAX     (*(volatile uint8_t *)0xD41F)  /* Máximo de los 3 (extendido) */

/* Modos de VU meter */
#define VU_MODE_MAX     0   /* 6 LEDs muestran el máximo de las 3 voces */
#define VU_MODE_3CH     1   /* 2 LEDs por canal (V1=LED1-2, V2=LED3-4, V3=LED5-6) */
#define VU_MODE_OFF     2   /* VU meter apagado */
#define VU_MODE_COUNT   3

/* Funciones ASM del player */
extern void sid_clear(void);
extern void sid_copy_to_memory(uint8_t *src, uint16_t dest, uint16_t len);
extern void sid_call(uint16_t addr);
extern void sid_init_song(uint16_t addr, uint8_t song);
extern uint16_t rom_read_file(void *buf, uint16_t len);  /* Wrapper ASM para ROM API */

/* ============================================================================
 * ESTRUCTURA PSID HEADER
 * ============================================================================ */
typedef struct {
    char     magic[4];      /* "PSID" o "RSID" */
    uint16_t version;       /* Versión (big-endian) */
    uint16_t dataOffset;    /* Offset a datos SID */
    uint16_t loadAddress;   /* Dirección de carga */
    uint16_t initAddress;   /* Dirección de init */
    uint16_t playAddress;   /* Dirección de play */
    uint16_t songs;         /* Número de canciones */
    uint16_t startSong;     /* Canción inicial (1-based) */
    uint32_t speed;         /* Flags de velocidad */
    char     name[32];      /* Nombre de la canción */
    char     author[32];    /* Autor */
    char     copyright[32]; /* Copyright */
} psid_header_t;

/* ============================================================================
 * VARIABLES GLOBALES
 * ============================================================================ */
static psid_header_t header;
static uint8_t file_buffer[100];   /* Buffer de lectura (reducido) */
static uint8_t current_song;       /* Canción actual (0-based) */
static uint8_t total_songs;        /* Total de canciones */
static uint8_t paused;             /* Estado de pausa */
static uint8_t vu_mode;            /* Modo VU meter (0=Max, 1=3ch, 2=Off) */
static uint16_t init_addr;         /* Dirección init */
static uint16_t play_addr;         /* Dirección play */
static uint16_t load_addr;         /* Dirección de carga */
static uint32_t timer_last;        /* Timer para timing */

/* ============================================================================
 * FUNCIONES UART (usando ROM API)
 * ============================================================================ */
void uart_puts(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

void uart_print_hex8(uint8_t val) {
    static const char hex[] = "0123456789ABCDEF";
    rom_uart_putc(hex[val >> 4]);
    rom_uart_putc(hex[val & 0x0F]);
}

void uart_print_hex16(uint16_t val) {
    uart_print_hex8(val >> 8);
    uart_print_hex8(val & 0xFF);
}

void uart_print_dec(uint8_t val) {
    if (val >= 100) rom_uart_putc('0' + val / 100);
    if (val >= 10)  rom_uart_putc('0' + (val / 10) % 10);
    rom_uart_putc('0' + val % 10);
}

void print_newline(void) {
    rom_uart_putc('\r');
    rom_uart_putc('\n');
}

/* ============================================================================
 * UTILIDADES
 * ============================================================================ */

/* Convertir big-endian a little-endian (16-bit) */
uint16_t swap16(uint16_t val) {
    return ((val & 0xFF) << 8) | ((val >> 8) & 0xFF);
}

/* Leer línea desde UART */
void read_line(char *buf, uint8_t max) {
    uint8_t i = 0;
    char c;
    
    while (i < max - 1) {
        c = rom_uart_getc();
        
        if (c == '\r' || c == '\n') {
            break;
        }
        else if (c == '\b' || c == 127) {
            if (i > 0) {
                i--;
                uart_puts("\b \b");
            }
        }
        else if (c >= ' ') {
            buf[i++] = c;
            rom_uart_putc(c);
        }
    }
    buf[i] = '\0';
    print_newline();
}

/* Convertir a mayúsculas */
void to_upper(char *s) {
    while (*s) {
        if (*s >= 'a' && *s <= 'z') {
            *s -= 32;
        }
        s++;
    }
}

/* ============================================================================
 * TIMER - Para timing de 60Hz
 * ============================================================================ */
uint32_t timer_read(void) {
    uint32_t t;
    TIMER_LATCH = LATCH_USEC;
    t = TIMER_USEC_0;
    t |= ((uint32_t)TIMER_USEC_1 << 8);
    t |= ((uint32_t)TIMER_USEC_2 << 16);
    t |= ((uint32_t)TIMER_USEC_3 << 24);
    return t;
}

/* Esperar N microsegundos desde última llamada */
void timer_wait_frame(void) {
    /* 16667 us = 60Hz (NTSC timing) - más rápido que PAL */
    uint32_t target = timer_last + 16667;
    uint32_t now;
    
    do {
        now = timer_read();
    } while (now < target);
    
    timer_last = now;
}

/* ============================================================================
 * PARSEAR HEADER PSID
 * ============================================================================ */
uint8_t parse_psid_header(void) {
    /* Verificar magic */
    if (header.magic[0] != 'P' && header.magic[0] != 'R') return 0;
    if (header.magic[1] != 'S') return 0;
    if (header.magic[2] != 'I') return 0;
    if (header.magic[3] != 'D') return 0;
    
    /* Convertir valores big-endian */
    header.version     = swap16(header.version);
    header.dataOffset  = swap16(header.dataOffset);
    header.loadAddress = swap16(header.loadAddress);
    header.initAddress = swap16(header.initAddress);
    header.playAddress = swap16(header.playAddress);
    header.songs       = swap16(header.songs);
    header.startSong   = swap16(header.startSong);
    
    return 1;
}

/* ============================================================================
 * MOSTRAR INFO DEL SID
 * ============================================================================ */
void show_sid_info(void) {
    uart_puts("\r\n");
    uart_puts("--------------------------------\r\n");
    
    /* Nombre */
    uart_puts("Titulo: ");
    header.name[31] = '\0';
    uart_puts(header.name);
    print_newline();
    
    /* Autor */
    uart_puts("Autor:  ");
    header.author[31] = '\0';
    uart_puts(header.author);
    print_newline();
    
    /* Copyright */
    uart_puts("(C):    ");
    header.copyright[31] = '\0';
    uart_puts(header.copyright);
    print_newline();
    
    /* Info técnica */
    uart_puts("--------------------------------\r\n");
    uart_puts("Canciones: ");
    uart_print_dec(total_songs);
    uart_puts("  |  Load: $");
    uart_print_hex16(load_addr);
    print_newline();
    uart_puts("Init: $");
    uart_print_hex16(init_addr);
    uart_puts("  |  Play: $");
    uart_print_hex16(play_addr);
    print_newline();
    uart_puts("--------------------------------\r\n");
    uart_puts("[ESPACIO]=Pausa [N/P]=Cancion [Q]=Salir\r\n");
    uart_puts("================================\r\n");
}

/* ============================================================================
 * MOSTRAR ESTADO ACTUAL
 * ============================================================================ */
void show_status(void) {
    uart_puts("\rCancion: ");
    uart_print_dec(current_song + 1);
    rom_uart_putc('/');
    uart_print_dec(total_songs);
    
    if (paused) {
        uart_puts(" [PAUSA]  ");
    } else {
        uart_puts(" [>>>]    ");
    }
}

/* ============================================================================
 * CARGAR SID POR XMODEM
 * ============================================================================ */
uint8_t load_sid_xmodem(void) {
    int bytes;
    uint16_t data_size;
    uint8_t *src;
    
    /* Recibe a $0800 - área de SIDs */
    uart_puts("XMODEM listo...\r\n");
    bytes = rom_xmodem_receive(0x0800);
    
    if (bytes <= 0) {
        uart_puts("Error\r\n");
        return 0;
    }
    
    /* Copiar header a variable global */
    memcpy(&header, (void*)0x0800, sizeof(header));
    
    if (!parse_psid_header()) {
        uart_puts("No es PSID\r\n");
        return 0;
    }
    
    total_songs = (header.songs > 255) ? 255 : header.songs;
    current_song = (header.startSong > 0) ? header.startSong - 1 : 0;
    init_addr = header.initAddress;
    play_addr = header.playAddress;
    
    if (header.loadAddress == 0) {
        src = (uint8_t *)(0x0800 + header.dataOffset);
        load_addr = src[0] | ((uint16_t)src[1] << 8);
        src += 2;
        data_size = bytes - header.dataOffset - 2;
    } else {
        load_addr = header.loadAddress;
        src = (uint8_t *)(0x0800 + header.dataOffset);
        data_size = bytes - header.dataOffset;
    }
    
    /* Verificar límites: SID debe cargar en $0800-$26FF */
    if (load_addr < 0x0800 || load_addr + data_size > 0x2700) {
        uart_puts("No cabe\r\n");
        return 0;
    }
    
    /* Copiar datos SID a su destino */
    /* sid_copy_to_memory detecta solapamiento y copia hacia atrás si es necesario */
    sid_copy_to_memory(src, load_addr, data_size);
    
    uart_puts("OK $");
    uart_print_hex16(load_addr);
    print_newline();
    return 1;
}

/* ============================================================================
 * CARGAR ARCHIVO SID DESDE SD
 * ============================================================================ */
uint8_t load_sid_file(const char *filename) {
    uint16_t file_size;
    uint16_t data_size;
    uint16_t bytes_read;
    uint16_t dest;
    uint16_t to_skip;
    uint16_t chunk;
    uint8_t skip_buf[2];
    
    /* Abrir archivo usando ROM API */
    if (rom_mfs_open(filename) != 0) {
        uart_puts("Error: Archivo no encontrado\r\n");
        return 0;
    }
    
    file_size = rom_mfs_get_size();
    uart_puts("Cargando: ");
    uart_puts(filename);
    uart_puts(" (");
    uart_print_dec(file_size / 1024);
    uart_puts(" KB, ");
    uart_print_hex16(file_size);
    uart_puts(" bytes)\r\n");
    
    /* Leer header PSID (76 bytes mínimo) */
    bytes_read = rom_read_file(&header, sizeof(header));
    
    if (bytes_read < 76) {  /* Mínimo header v1 */
        uart_puts("Error: Header muy corto\r\n");
        rom_mfs_close();
        return 0;
    }
    
    /* Parsear header */
    if (!parse_psid_header()) {
        uart_puts("Error: No es archivo PSID/RSID\r\n");
        rom_mfs_close();
        return 0;
    }
    
    /* Guardar info */
    total_songs = (header.songs > 255) ? 255 : header.songs;
    current_song = (header.startSong > 0) ? header.startSong - 1 : 0;
    init_addr = header.initAddress;
    play_addr = header.playAddress;
    
    /* Si loadAddress es 0, los primeros 2 bytes de datos son la dirección */
    if (header.loadAddress == 0) {
        /* Posicionar al inicio de datos */
        rom_mfs_close();
        rom_mfs_open(filename);
        
        /* Saltar header */
        to_skip = header.dataOffset;
        while (to_skip > 0) {
            chunk = (to_skip > sizeof(file_buffer)) ? sizeof(file_buffer) : to_skip;
            rom_read_file(file_buffer, chunk);
            to_skip -= chunk;
        }
        
        /* Primeros 2 bytes son load address (little-endian) */
        rom_read_file(skip_buf, 2);
        load_addr = skip_buf[0] | ((uint16_t)skip_buf[1] << 8);
        data_size = file_size - header.dataOffset - 2;
    } else {
        load_addr = header.loadAddress;
        /* Cerrar y reabrir para posicionar */
        rom_mfs_close();
        rom_mfs_open(filename);
        
        /* Saltar header */
        to_skip = header.dataOffset;
        while (to_skip > 0) {
            chunk = (to_skip > sizeof(file_buffer)) ? sizeof(file_buffer) : to_skip;
            rom_read_file(file_buffer, chunk);
            to_skip -= chunk;
        }
        data_size = file_size - header.dataOffset;
    }
    
    /* Verificar que cabe en RAM sin colisionar con el programa (en $2700+) */
    if (load_addr < 0x0800 || load_addr + data_size > 0x2700) {
        uart_puts("Error: SID no cabe en RAM\r\n");
        uart_puts("  Load: $");
        uart_print_hex16(load_addr);
        uart_puts(" End: $");
        uart_print_hex16(load_addr + data_size);
        uart_puts(" (max $2700)\r\n");
        rom_mfs_close();
        return 0;
    }
    
    uart_puts("Copiando ");;
    uart_print_dec(data_size / 256);
    uart_puts(" paginas a $");
    uart_print_hex16(load_addr);
    print_newline();
    
    /* Cargar datos a memoria */
    dest = load_addr;
    while (data_size > 0) {
        chunk = (data_size > sizeof(file_buffer)) ? sizeof(file_buffer) : data_size;
        bytes_read = rom_read_file(file_buffer, chunk);
        if (bytes_read == 0) break;
        
        /* Copiar a memoria de destino */
        sid_copy_to_memory(file_buffer, dest, bytes_read);
        
        dest += bytes_read;
        data_size -= bytes_read;
        
        /* Indicador de progreso */
        rom_uart_putc('.');
    }
    print_newline();
    
    rom_mfs_close();
    
    uart_puts("Cargado OK!\r\n");
    return 1;
}

/* ============================================================================
 * INICIALIZAR CANCIÓN
 * ============================================================================ */
void init_song(uint8_t song_num) {
    /* Limpiar SID */
    sid_clear();
    
    /* Llamar init con número de canción en A */
    sid_init_song(init_addr, song_num);
    
    /* Iniciar timer */
    timer_last = timer_read();
    
    /* Actualizar LEDs - patrón según canción */
    LEDS = ~(1 << (song_num % 6));
    
    show_status();
}

/* ============================================================================
 * MAIN
 * ============================================================================ */
int main(void) {
    char filename[16];
    char key;
    uint8_t num;
    uint8_t pattern;
    uint8_t result;
    
    /* Apagar LEDs al inicio */
    LEDS = 0xFF;
    
    /* Banner */
    uart_puts("\r\n");
    uart_puts("================================\r\n");
    uart_puts("  SID PLAYER 6502 v1.2.1\r\n");
    uart_puts("  V=VU mode (Max/3ch/Off)\r\n");
    uart_puts("================================\r\n\r\n");
    
    /* Intentar montar filesystem (por si no está montado) */
    uart_puts("Montando SD...");
    result = rom_mfs_mount();
    if (result != 0) {
        uart_puts("Error!\r\n");
        return 1;
    }
    uart_puts("OK\r\n\r\n");
    
    /* Loop principal - permitir cargar múltiples SIDs */
    while (1) {
        /* Pedir nombre de archivo */
        uart_puts("SID (Q=salir, X=XMODEM): ");
        read_line(filename, sizeof(filename));
        to_upper(filename);
        
        /* Salir? */
        if (filename[0] == 'Q' && filename[1] == '\0') {
            sid_clear();
            uart_puts("Hasta luego!\r\n");
            return 0;
        }
        
        /* XMODEM? */
        if (filename[0] == 'X' && filename[1] == '\0') {
            if (!load_sid_xmodem()) {
                continue;
            }
        } else {
            /* Agregar extensión si falta */
            if (strlen(filename) > 0 && strstr(filename, ".SID") == 0) {
                if (strlen(filename) < 12) {
                    strcat(filename, ".SID");
                }
            }
            
            /* Cargar archivo desde SD */
            if (!load_sid_file(filename)) {
                continue;
            }
        }
        
        /* Mostrar info */
        show_sid_info();
        
        /* Inicializar primera canción */
        paused = 0;
        vu_mode = VU_MODE_MAX;  /* VU meter activado por defecto */
        LEDS = 0xFF;           /* Apagar LEDs al iniciar */
        init_song(current_song);
        
        /* Loop de reproducción */
        while (1) {
            /* Verificar tecla */
            if (rom_uart_rx_ready()) {
                key = rom_uart_getc();
                
                switch (key) {
                    case ' ':  /* Pausa/Play */
                        paused = !paused;
                        if (paused) {
                            sid_clear();  /* Silenciar al pausar */
                            LEDS = 0xFF;  /* Apagar LEDs al pausar */
                        } else {
                            timer_last = timer_read();
                        }
                        show_status();
                        break;
                        
                    case 'n':
                    case 'N':  /* Siguiente */
                        if (current_song < total_songs - 1) {
                            current_song++;
                        } else {
                            current_song = 0;
                        }
                        init_song(current_song);
                        break;
                        
                    case 'p':
                    case 'P':  /* Anterior */
                        if (current_song > 0) {
                            current_song--;
                        } else {
                            current_song = total_songs - 1;
                        }
                        init_song(current_song);
                        break;
                        
                    case 'q':
                    case 'Q':  /* Salir - volver a pedir archivo */
                        sid_clear();
                        LEDS = 0xFF;
                        print_newline();
                        goto next_file;
                        
                    case 'v':
                    case 'V':  /* Cambiar modo VU meter */
                        vu_mode = (vu_mode + 1) % VU_MODE_COUNT;
                        LEDS = 0xFF;  /* Apagar LEDs al cambiar */
                        uart_puts("\rVU: ");
                        if (vu_mode == VU_MODE_MAX) uart_puts("Max ");
                        else if (vu_mode == VU_MODE_3CH) uart_puts("3ch ");
                        else uart_puts("Off ");
                        break;
                        
                    default:
                        /* Números 1-9 para ir a canción */
                        if (key >= '1' && key <= '9') {
                            num = key - '1';
                            if (num < total_songs) {
                                current_song = num;
                                init_song(current_song);
                            }
                        }
                        break;
                }
            }
            
            /* Si no está pausado, reproducir frame */
            if (!paused && play_addr != 0) {
                /* Llamar rutina play */
                sid_call(play_addr);
                
                /* Esperar siguiente frame (50Hz) */
                timer_wait_frame();
                
                /* VU meter según modo seleccionado */
                pattern = 0;
                if (vu_mode == VU_MODE_MAX) {
                    /* Modo Max: 6 LEDs muestran el máximo de las 3 voces */
                    num = SID_ENV_MAX;
                    if (num > 20)  pattern |= 0x01;
                    if (num > 60)  pattern |= 0x02;
                    if (num > 100) pattern |= 0x04;
                    if (num > 140) pattern |= 0x08;
                    if (num > 180) pattern |= 0x10;
                    if (num > 220) pattern |= 0x20;
                }
                else if (vu_mode == VU_MODE_3CH) {
                    /* Modo 3 canales: 2 LEDs por voz */
                    /* Voz 1: LED 1-2 */
                    num = SID_ENV1;
                    if (num > 40)  pattern |= 0x01;
                    if (num > 140) pattern |= 0x02;
                    /* Voz 2: LED 3-4 */
                    num = SID_ENV2;
                    if (num > 40)  pattern |= 0x04;
                    if (num > 140) pattern |= 0x08;
                    /* Voz 3: LED 5-6 */
                    num = SID_ENV3;
                    if (num > 40)  pattern |= 0x10;
                    if (num > 140) pattern |= 0x20;
                }
                /* VU_MODE_OFF: pattern queda en 0 */
                LEDS = ~pattern;  /* LEDs activos en bajo */
            }
        }
        
next_file:
        continue;
    }
    
    return 0;
}
