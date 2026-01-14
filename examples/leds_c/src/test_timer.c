/**
 * Test directo del timer hardware
 */

#include <stdint.h>

#define TIMER_USEC_0    (*(volatile uint8_t *)0xC038)
#define TIMER_USEC_1    (*(volatile uint8_t *)0xC039)
#define TIMER_USEC_2    (*(volatile uint8_t *)0xC03A)
#define TIMER_USEC_3    (*(volatile uint8_t *)0xC03B)
#define TIMER_LATCH     (*(volatile uint8_t *)0xC03C)

#define LEDS            (*(volatile uint8_t *)0xC001)

#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)
#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)

void uart_print(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

void print_hex(uint8_t val) {
    char hex[] = "0123456789ABCDEF";
    rom_uart_putc(hex[val >> 4]);
    rom_uart_putc(hex[val & 0x0F]);
}

void main(void) {
    uint8_t b0, b1, b2, b3;
    uint8_t i;
    
    uart_print("\n\nTest Timer Hardware\n");
    uart_print("===================\n\n");
    
    // Leer contador varias veces
    for (i = 0; i < 5; i++) {
        // Latch
        TIMER_LATCH = 0x02;
        
        // Leer
        b0 = TIMER_USEC_0;
        b1 = TIMER_USEC_1;
        b2 = TIMER_USEC_2;
        b3 = TIMER_USEC_3;
        
        uart_print("Timer: 0x");
        print_hex(b3);
        print_hex(b2);
        print_hex(b1);
        print_hex(b0);
        uart_print("\n");
        
        // Toggle LED
        LEDS = ~(1 << i);
        
        // Busy wait
        {
            uint16_t j;
            for (j = 0; j < 30000; j++);
        }
    }
    
    uart_print("\nTest completado\n");
    LEDS = 0xFF;
}
