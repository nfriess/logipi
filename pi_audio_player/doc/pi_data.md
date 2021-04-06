# Data transfer between Raspberry Pi and Logi-Pi

All of the audio data transferred from the Raspberry Pi to the Logi-Pi happens
through SPI.  The Logi-Pi assumes the following settings:

* Mode: 0
* Bits: 8
* Speed: 32 MHz
* Delay between CE and transfer: 0

A transfer must start with a 32 bit address and then contain 32 bit words for
each audio sample.  Typically the address will be either 0 or half the total
address space of the SRAM buffer, although the Linux Kernel SPI driver contains
a limited size buffer, so of multiple transfers are needed to fill half of the
Logi-Pi's SRAM buffer then any amount of data can be transferred to any address
to refill the SRAM FIFO.

The topmost bit of the address must always be '1' signalling a "write"
operation.  Read operations are not supported.  Addresses are in big endian
format.

The data that follows are 32-bit words that contain 24-bit samples, right-
justified.  The upper 8 bits are unused but may be used in the future for
other "inline" signals.  The Ethernet interface used some of the upper bits,
for example.  Data is in little endian format.
