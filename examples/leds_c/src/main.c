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
 *   - rom_uart_init()   - Inicializar UART
 *   - rom_uart_puts()   - Enviar string
 * ============================================================================
 */

#include <stdint.h>

/* ============================================================================
 * HARDWARE
 * ============================================================================ */
#define LEDS            (*(volatile uint8_t *)0xC001)   /* LEDs (lógica negativa) */

/* Timer - 32-bit microsecond counter */
#define TIMER_USEC_0    (*(volatile uint8_t *)0xC038)
#define TIMER_USEC_1    (*(volatile uint8_t *)0xC039)
#define TIMER_USEC_2    (*(volatile uint8_t *)0xC03A)
#define TIMER_USEC_3    (*(volatile uint8_t *)0xC03B)
#define TIMER_LATCH     (*(volatile uint8_t *)0xC03C)
#define LATCH_USEC      0x02

/* ============================================================================
 * ROM API - UART
 * ============================================================================ */

/* Definir punteros a funciones en ROM */
#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)

/* Macro para llamar función de ROM */
#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)

/* Función para enviar strings usando ROM API */
void uart_print(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

/* ============================================================================
 * FUNCIONES DE DELAY
 * ============================================================================ */

/**
 * Leer timer de microsegundos (32-bit)
 */
uint32_t timer_read(void) {
    uint32_t t;
    TIMER_LATCH = LATCH_USEC;
    t = TIMER_USEC_0;
    t |= ((uint32_t)TIMER_USEC_1 << 8);
    t |= ((uint32_t)TIMER_USEC_2 << 16);
    t |= ((uint32_t)TIMER_USEC_3 << 24);
    return t;
}

/**
 * Delay en microsegundos
 */
void delay_us(uint32_t us) {
    uint32_t start = timer_read();
    uint32_t target = start + us;
    
    while (timer_read() < target) {
        /* Esperar */
    }
}

/**
 * Delay corto (~100ms)
 */
void delay_short(void) {
    delay_us(100000);   /* 100ms */
}

/**
 * Delay largo (~300ms)
 */
void delay_long(void) {
    delay_us(300000);   /* 300ms */
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
