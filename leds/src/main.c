/*
 * main.c - Efecto de luces LED para Monitor 6502
 * Tang Nano 9K - Compilado con cc65
 */

/* Puerto de LEDs */
#define LEDS    (*(volatile unsigned char *)0xC001)

/* Delay simple - ajustar según velocidad deseada */
void delay(unsigned int count) {
    while (count--) {
        /* Bucle vacío para generar delay */
        __asm__("nop");
    }
}

/* Delay largo usando múltiples delays cortos */
void delay_long(unsigned char times) {
    while (times--) {
        delay(0xFFFF);
    }
}

/* Efecto 1: Knight Rider (luz que va y viene) */
void effect_knight_rider(unsigned char cycles) {
    unsigned char led, i;
    
    while (cycles--) {
        /* Ida: derecha a izquierda */
        led = 0x01;
        for (i = 0; i < 6; i++) {
            LEDS = ~led;        /* LEDs activos en bajo */
            delay_long(1);
            led <<= 1;
        }
        
        /* Vuelta: izquierda a derecha */
        led = 0x20;
        for (i = 0; i < 6; i++) {
            LEDS = ~led;
            delay_long(1);
            led >>= 1;
        }
    }
}

/* Efecto 2: Contador binario */
void effect_counter(unsigned char max) {
    unsigned char count = 0;
    
    while (count < max) {
        LEDS = ~count;          /* Mostrar valor invertido */
        delay_long(2);
        count++;
    }
}

/* Efecto 3: Parpadeo alterno */
void effect_blink_alternate(unsigned char cycles) {
    while (cycles--) {
        LEDS = 0x55;            /* 01010101 */
        delay_long(2);
        LEDS = 0xAA;            /* 10101010 */
        delay_long(2);
    }
}

/* Efecto 4: Todos encendidos/apagados */
void effect_all_blink(unsigned char cycles) {
    while (cycles--) {
        LEDS = 0x00;            /* Todos ON (activo bajo) */
        delay_long(1);
        LEDS = 0xFF;            /* Todos OFF */
        delay_long(1);
    }
}

/* Efecto 5: Llenado progresivo */
void effect_fill(unsigned char cycles) {
    unsigned char led, i;
    
    while (cycles--) {
        /* Llenar de derecha a izquierda */
        led = 0x00;
        for (i = 0; i < 6; i++) {
            led |= (1 << i);
            LEDS = ~led;
            delay_long(1);
        }
        
        /* Vaciar de izquierda a derecha */
        for (i = 0; i < 6; i++) {
            led &= ~(0x20 >> i);
            LEDS = ~led;
            delay_long(1);
        }
    }
}

/* Función principal */
int main(void) {
    /* Bucle infinito de efectos */
    while (1) {
        /* Knight Rider - 3 ciclos */
        effect_knight_rider(3);
        
        /* Contador hasta 64 */
        effect_counter(64);
        
        /* Parpadeo alterno - 5 ciclos */
        effect_blink_alternate(5);
        
        /* Llenado - 2 ciclos */
        effect_fill(2);
        
        /* Parpadeo todos - 4 ciclos */
        effect_all_blink(4);
    }
    
    return 0;
}
