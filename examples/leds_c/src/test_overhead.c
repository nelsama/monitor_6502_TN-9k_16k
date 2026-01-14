/**
 * Test de overhead del bucle get_micros
 */

#include <stdint.h>

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

void main(void) {
    uint32_t t1, t2, target;
    uint16_t i, count;
    
    uart_print("\n\nTest Overhead get_micros\n");
    uart_print("========================\n\n");
    
    // Test 1: Medir tiempo de 100 llamadas a get_micros()
    uart_print("100 llamadas a get_micros():\n");
    
    t1 = rom_get_micros();
    for (i = 0; i < 100; i++) {
        rom_get_micros();
    }
    t2 = rom_get_micros();
    
    uart_print("  Tiempo total: ");
    print_u32(t2 - t1);
    uart_print(" us\n");
    
    uart_print("  Por llamada: ~");
    print_hex((uint8_t)((t2 - t1) / 100));
    uart_print(" us\n\n");
    
    // Test 2: Simular el bucle de delay
    uart_print("Simular delay_us(100):\n");
    
    t1 = rom_get_micros();
    target = t1 + 100;
    count = 0;
    
    while (rom_get_micros() < target) {
        count++;
    }
    
    t2 = rom_get_micros();
    
    uart_print("  Iteraciones: ");
    print_hex((uint8_t)(count >> 8));
    print_hex((uint8_t)(count));
    uart_print("\n");
    
    uart_print("  Tiempo real: ");
    print_u32(t2 - t1);
    uart_print(" us\n");
    
    uart_print("\nTest completado\n");
}
