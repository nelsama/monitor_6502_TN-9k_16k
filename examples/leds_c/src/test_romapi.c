/**
 * Test directo de ROM API timer
 */

#include <stdint.h>

#define LEDS                (*(volatile uint8_t *)0xC001)

#define ROMAPI_UART_PUTC    ((void (*)(char))0xBF18)
#define ROMAPI_GET_MICROS   ((uint32_t (*)(void))0xBF2D)
#define ROMAPI_DELAY_US     ((void (*)(uint16_t))0xBF30)
#define ROMAPI_DELAY_MS     ((void (*)(uint16_t))0xBF33)

#define rom_uart_putc(c)    ROMAPI_UART_PUTC(c)
#define rom_get_micros()    ROMAPI_GET_MICROS()
#define rom_delay_us(us)    ROMAPI_DELAY_US(us)
#define rom_delay_ms(ms)    ROMAPI_DELAY_MS(ms)

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
    uint32_t t1, t2;
    uint8_t i;
    
    uart_print("\n\nTest ROM API Timer\n");
    uart_print("==================\n\n");
    
    // Test get_micros
    uart_print("1. Test get_micros:\n");
    for (i = 0; i < 3; i++) {
        t1 = rom_get_micros();
        uart_print("   t = 0x");
        print_u32(t1);
        uart_print("\n");
    }
    
    // Test delay_us (100us)
    uart_print("\n2. Test delay_us(100):\n");
    t1 = rom_get_micros();
    uart_print("   Antes:  0x");
    print_u32(t1);
    uart_print("\n");
    
    uart_print("   Llamando delay_us(100)...\n");
    rom_delay_us(100);
    
    t2 = rom_get_micros();
    uart_print("   Despues: 0x");
    print_u32(t2);
    uart_print("\n");
    uart_print("   Delta: ");
    print_u32(t2 - t1);
    uart_print(" us\n");
    
    // Test delay_ms (100ms) con LEDs
    uart_print("\n3. Test delay_ms(100) con LEDs:\n");
    for (i = 0; i < 6; i++) {
        uart_print("   LED ");
        rom_uart_putc('0' + i);
        uart_print(" ON\n");
        
        LEDS = ~(1 << i);
        rom_delay_ms(100);
    }
    
    uart_print("\nTest completado\n");
    LEDS = 0xFF;
}
