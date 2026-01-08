// xmodem.h - XMODEM Protocol Implementation for 6502 Monitor
// Implements XMODEM-128 (128-byte blocks with checksum)

#ifndef XMODEM_H
#define XMODEM_H

// XMODEM Protocol Constants
#define XMODEM_SOH  0x01  // Start of Header
#define XMODEM_EOT  0x04  // End of Transmission
#define XMODEM_ACK  0x06  // Acknowledge
#define XMODEM_NAK  0x15  // Negative Acknowledge
#define XMODEM_CAN  0x18  // Cancel
#define XMODEM_BLOCK_SIZE 128

// Error codes (negative values)
#define XMODEM_ERROR_TIMEOUT   -1
#define XMODEM_ERROR_CANCELLED -2
#define XMODEM_ERROR_SYNC      -3
#define XMODEM_ERROR_CHECKSUM  -4

// Function: xmodem_receive
// Receives a file via XMODEM protocol and stores it at dest_addr
// Parameters:
//   dest_addr - Starting memory address to store received data
// Returns:
//   Number of bytes received (positive) on success
//   Error code (negative) on failure
int xmodem_receive(unsigned int dest_addr);

#endif // XMODEM_H
