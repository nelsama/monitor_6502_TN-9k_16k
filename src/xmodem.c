// xmodem.c - XMODEM para 6502
#include "xmodem.h"
#include "../libs/uart-6502-cc65/uart.h"

#define SOH  0x01
#define EOT  0x04
#define ACK  0x06
#define NAK  0x15
#define CAN  0x18

/* Limites de espera. Se declaran como variables unsigned int para que cc65
 * no promocione la comparacion a long de 32 bits: 50000/60000 no caben en
 * un int de 16 bits y el bucle acabaria usando axulong, pusheax y toslteax,
 * que son mas lentos y pisan sreg/ptr1/ptr2 (recursos del UART). */
static const unsigned int TIMEOUT_SOH   = 0xC350;  /* 50000 */
static const unsigned int TIMEOUT_BLOCK = 0xEA60;  /* 60000 */

int xmodem_receive(unsigned int dest_addr) {
    unsigned char *dest = (unsigned char *)dest_addr;
    unsigned char blk_expected = 1;
    unsigned int bytes_received = 0;
    unsigned char header, blk_num, blk_inv, checksum, calc_sum;
    unsigned char i;
    unsigned char nak_count;
    unsigned int timeout;
    
    // Enviar NAKs hasta recibir SOH (máximo 60 intentos)
    for (nak_count = 0; nak_count < 60; nak_count++) {
        uart_putc(NAK);
        
        // Esperar respuesta con timeout
        for (timeout = 0; timeout < TIMEOUT_SOH; timeout++) {
            if (uart_rx_ready()) {
                header = uart_getc();
                if (header == SOH) goto process_block;
                if (header == EOT) { uart_putc(ACK); return (int)bytes_received; }
                if (header == CAN) return -2;
            }
        }
    }
    return -1;

process_block:
    // Leer bloque
    blk_num = uart_getc();
    blk_inv = uart_getc();
    
    calc_sum = 0;
    for (i = 0; i < 128; i++) {
        dest[i] = uart_getc();
        calc_sum += dest[i];
    }
    checksum = uart_getc();
    
    // Validar y responder
    if ((blk_num + blk_inv) == 255 && calc_sum == checksum && blk_num == blk_expected) {
        uart_putc(ACK);
        dest += 128;
        bytes_received += 128;
        blk_expected++;
    } else if (blk_num == (unsigned char)(blk_expected - 1)) {
        uart_putc(ACK);
    } else {
        uart_putc(NAK);
    }
    
    // Esperar siguiente con timeout
    for (timeout = 0; timeout < TIMEOUT_BLOCK; timeout++) {
        if (uart_rx_ready()) {
            header = uart_getc();
            if (header == SOH) goto process_block;
            if (header == EOT) { uart_putc(ACK); return (int)bytes_received; }
            if (header == CAN) return -2;
        }
    }
    
    // Timeout esperando siguiente bloque - asumir fin
    return (int)bytes_received;
}
