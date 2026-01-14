/**
 * Test simple de LEDs sin delays
 */

#include <stdint.h>

#define LEDS            (*(volatile uint8_t *)0xC001)
#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)
#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)

void uart_print(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

void main(void) {
    uint8_t i;
    uint16_t j;
    
    uart_print("\n\nTest LEDs simple\n");
    
    // Encender LEDs uno por uno sin delay
    for (i = 0; i < 6; i++) {
        uart_print("LED ");
        rom_uart_putc('0' + i);
        uart_print(" ON\n");
        
        LEDS = ~(1 << i);  // Encender LED i
        
        // Delay manual (muy lento)
        for (j = 0; j < 10000; j++) {
            // busy wait
        }
    }
    
    uart_print("Test completado\n");
    LEDS = 0xFF;  // Apagar todos
}
