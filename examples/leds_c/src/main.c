/**
 * ============================================================================
 * LEDS Demo - Plantilla de programa en C para Monitor 6502
 * ============================================================================
 * Efecto Knight Rider usando LEDs y ROM API
 * 
 * Características:
 *   - Usa ROM API para timer y UART (no incluye librerías)
 *   - Dirección de carga: $0800
 *   - Timing preciso con timer hardware
 * 
 * Uso:
 *   LOAD LEDS_C 0800
 *   R 0800
 * 
 * ROM API utilizada:
 *   - rom_uart_putc()   - Enviar caracteres
 *   - rom_delay_ms()    - Delays en milisegundos
 * ============================================================================
 */

#include <stdint.h>

/* ============================================================================
 * ROM API - Timer y UART
 * ============================================================================ */

/* Timer */
#define ROMAPI_DELAY_MS     ((void (*)(uint16_t))0xBF33)
#define rom_delay_ms(ms)    ROMAPI_DELAY_MS(ms)

/* UART */
#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)
#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)

/* ============================================================================
 * HARDWARE
 * ============================================================================ */
#define LEDS            (*(volatile uint8_t *)0xC001)   /* LEDs (lógica negativa) */

/* Función para enviar strings usando ROM API */
void uart_print(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

/* ============================================================================
 * FUNCIONES DE DELAY (usando ROM API)
 * ============================================================================ */

/**
 * Delay corto (~100ms)
 */
void delay_short(void) {
    rom_delay_ms(100);   /* 100ms */
}

/**
 * Delay largo (~300ms)
 */
void delay_long(void) {
    rom_delay_ms(300);   /* 300ms */
}

/* ============================================================================
 * EFECTOS DE LEDS
 * ============================================================================ */

/**
 * Efecto Knight Rider - Luz que va y viene
 */
void effect_knight_rider(void) {
    uint8_t led;
    
    /* Ida: bit 0 -> bit 5 (derecha a izquierda) */
    led = 0x01;
    while (led < 0x40) {
        LEDS = ~led;        /* Lógica negativa: 0=encendido */
        delay_long();
        led <<= 1;
    }
    
    /* Vuelta: bit 5 -> bit 0 (izquierda a derecha) */
    led = 0x20;
    while (led > 0x01) {
        LEDS = ~led;
        delay_long();
        led >>= 1;
    }
    LEDS = ~led;            /* Mostrar último LED */
    delay_long();
}

/**
 * Efecto alternado - LEDs parpadean alternados
 */
void effect_alternate(void) {
    uint8_t i;
    
    for (i = 0; i < 5; i++) {
        LEDS = ~0x15;   /* 010101 */
        delay_short();
        LEDS = ~0x2A;   /* 101010 */
        delay_short();
    }
}

/**
 * Efecto secuencial - Encender LEDs uno por uno
 */
void effect_sequential(void) {
    uint8_t pattern = 0;
    uint8_t i;
    
    /* Encender uno por uno */
    for (i = 0; i < 6; i++) {
        pattern |= (1 << i);
        LEDS = ~pattern;
        delay_short();
    }
    
    /* Mantener todos encendidos */
    delay_long();
    
    /* Apagar todos */
    LEDS = 0xFF;
    delay_long();
}

/* ============================================================================
 * MAIN
 * ============================================================================ */

int main(void) {
    uint8_t mode = 0;
    
    /* Banner */
    uart_print("\r\n");
    uart_print("================================\r\n");
    uart_print("  LEDS Demo - Monitor 6502\r\n");
    uart_print("  Plantilla en C con ROM API\r\n");
    uart_print("================================\r\n");
    uart_print("Presiona CTRL+C para salir\r\n\r\n");
    
    /* Apagar LEDs al inicio */
    LEDS = 0xFF;
    delay_long();
    
    /* Loop principal - rotar entre efectos */
    while (1) {
        switch (mode) {
            case 0:
                effect_knight_rider();
                break;
            case 1:
                effect_alternate();
                break;
            case 2:
                effect_sequential();
                break;
        }
        
        /* Cambiar de efecto */
        mode++;
        if (mode > 2) {
            mode = 0;
        }
        
        /* Pausa entre efectos */
        delay_long();
    }
    
    return 0;
}
