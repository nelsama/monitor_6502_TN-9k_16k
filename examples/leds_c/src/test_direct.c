/**
 * Test directo vs ROM API
 */

#include <stdint.h>

#define TIMER_USEC_0    (*(volatile uint8_t *)0xC038)
#define TIMER_USEC_1    (*(volatile uint8_t *)0xC039)
#define TIMER_USEC_2    (*(volatile uint8_t *)0xC03A)
#define TIMER_USEC_3    (*(volatile uint8_t *)0xC03B)
#define TIMER_LATCH     (*(volatile uint8_t *)0xC03C)

#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)
#define ROMAPI_GET_MICROS   ((uint32_t (*)(void))0xBF2D)

#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)
#define rom_get_micros()    ROMAPI_GET_MICROS()

void uart_print(const char *s) {
    while (*s) rom_uart_putc(*s++);
}

void print_hex(uint8_t val) {
    char hex[] = "0123456789ABCDEF";
    rom_uart_putc(hex[val >> 4]);
    rom_uart_putc(hex[val & 0x0F]);
}

void print_u32(uint32_t val) {
    print_hex((uint8_t)(val >> 24));
    print_hex((uint8_t)(val >> 16));
    print_hex((uint8_t)(val >> 8));
    print_hex((uint8_t)(val));
}

uint32_t get_micros_direct(void) {
    uint32_t result;
    uint8_t *p = (uint8_t*)&result;
    
    TIMER_LATCH = 0x02;
    p[0] = TIMER_USEC_0;
    p[1] = TIMER_USEC_1;
    p[2] = TIMER_USEC_2;
    p[3] = TIMER_USEC_3;
    
    return result;
}

void main(void) {
    uint32_t t1, t2;
    uint16_t i;
    
    uart_print("\n\nTest Directo vs ROM API\n");
    uart_print("========================\n\n");
    
    // Test 1: Acceso directo (100 llamadas)
    uart_print("100 llamadas DIRECTAS:\n");
    t1 = get_micros_direct();
    for (i = 0; i < 100; i++) {
        get_micros_direct();
    }
    t2 = get_micros_direct();
    
    uart_print("  Total: ");
    print_u32(t2 - t1);
    uart_print(" us\n  Por llamada: ~");
    print_hex((uint8_t)((t2 - t1) / 100));
    uart_print(" us\n\n");
    
    // Test 2: ROM API (100 llamadas)
    uart_print("100 llamadas ROM API:\n");
    t1 = rom_get_micros();
    for (i = 0; i < 100; i++) {
        rom_get_micros();
    }
    t2 = rom_get_micros();
    
    uart_print("  Total: ");
    print_u32(t2 - t1);
    uart_print(" us\n  Por llamada: ~");
    print_hex((uint8_t)((t2 - t1) / 100));
    uart_print(" us\n\n");
    
    uart_print("Test completado\n");
}
