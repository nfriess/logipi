# Control registers between Raspberry Pi and Logi-Pi

To free up the SPI bus for maximum bandwidth in transferring audio data,
any other type of control communication uses the I2C bus at /dev/i2c-1.
The Logi-Pi is an I2C slave and responds to bus address 0x60.  Within
the I2C data is a typical structure of first presenting an 8-bit register
address and then 16-bits of data to read or write to/from the register.  The
16-bit data is in little endian order.

There is also one hard-wired interrupt signal that goes to GPIO pin 27
(pin 13 on the Pi's header).  This signal is logic '1' when more data is needed
to fill the SRAM buffer, and remains '1' until the Raspberry Pi transfers data
to the last address (or half address) of the the SRAM buffer.  Since the
Raspberry Pi may transfer data in small blocks or may have delays in responding
to the interrupt, this signal can be treated as a handshake where the value '1'
means that more blocks must be sent repeatedly until the value becomes '0'.

## Registers

### Identify

Address: 0

Always reads the value 0xDEAD to confirm that the Logi-Pi is connected and
powered on.

### Buffer Size

Address: 1

The top 8 bits are address size of the SRAM FIFO (in samples).  For example a
value of 14 means that there are 2^14 (16K) addresses.

The lower 8 bits indicate how often the interrupt will trigger.  It is the
address size of each complete transfer that is expected.  Continuing the
example, a value of 13 means that the SRAM FIFO is double buffered, and an
interrupt will trigger every time the Logi-Pi reads half of the SRAM buffer.

### Enable Register

Address: 2

Write a value of 0x0001 to enable the reading the FIFO and shifting data out
to the DACs.  When 0 the FIFO will not be used and the value "0" (silence) will
be continually shifted into the DACs.

### Reset Register

Address: 3

Write a value of 0x0001 to reset the FIFO reader state machine.  This is
necessary to reset the read address and any other state so the reader starts
from address 0 and in a known state.

### FIFO Read Addresss

Address: 4

For debugging purposes only, this will contain the FIFO read address.  A write
to this will move the FIFO read pointer to the specified address.  There are no
guards to prevent writing to this register while the FIFO reader is running
and in that case the resulting operation is undefined.

### FIFO Write Address

Address: 5

For debugging purposes only, this will contain the FIFO write address.  A write
to this will move the FIFO write pointer to the specified address.  Writing to
this register doesn't make much sense since every SPI transfer also starts with
the same address register, but reading from this can confirm that the address
register contains the expected result after the most recent SPI transfer.

### Missed Interrupt Count

Address: 6

After resetting the FIFO reader this will contain the value zero.  If at any
time the interrupt pin is logic '1' while the reader crosses the address where
another interrupt would be generated, this register is incremnted by 1.  This
register is useful to determine if the Raspberry Pi is a bit slow and not quite
keeping up to the interrupt frequency.

Writing any value to this register will clear it immediately.

### CE Count

Address: 7

After resetting the FIFO reader this will contain the value zero.  Every SPI
transfer (chip enable pin falls) will increment this register.  This then
counts the number of SPI transfers received.  Writing to this register will
do nothing.
