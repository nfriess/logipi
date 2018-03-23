# FPGA Overview

## Architecture

The VHDL design for the FPGA is divided into the following components:

* audio_player.vhd - The top-level module that interconnects all other
  components.  Arbitrates SDRAM access between the Ethernet and DAC
  controllers, and the Raspberry Pi internface (for debugging).

* ethernet_controller.vhd - Interfaces with the Microchip ENC424J600
  device and saves audio data to the SDRAM.

* spimaster.vhd - Drives the SPI signals to the ENC424J600 for the
  high-level ethernet controller.

* sdram_controller.v - Drives the SDRAM.

* dac_controller.vhd - Reads audio data from the SDRAM, stores it in
  the FGPA's internal SRRAM.  A separate state machine reads the data
  from SRAM and drives the D-to-As.  Also generates the bit clock and
  word clock for the D-to-As based on either the FGPA's internal clock
  or an external 16.9344 MHz clock.

* spi_wishbone_wrapper.vhd - An SPI slave device for the Raspberry PI
  to communicate with.  Borrowed from the logipi samples and modified
  slightly.

* wishbone_register.vhd - Defines registers for the spi_Wishbone device
  to connect to.  Registers are used to debug the state of various other
  components, or as an indirect method of reading and writing the SDRAM
  contents.

The spi_wishbone_wrapper and wishbone_register devices are not required
for the audio player project.  These only exist to allow for using a
connected Raspberry Pi to monitor and debug the VHDL during development.
In the final deployment there is no Raspberry Pi connected and so this
code is not used, but remains compiled in.


## Interconnections

**NOTE:** All references to the Wishbone bus are slightly modified from
the official Wishbone specification.  It seems simpler to make the
ACK signal synchronous with the STROBE signals, so that when an access
cycle is complete, the slave device holds the ACK signal active until
the master deactivates STROBE.


### Ethernet controller

The Ethernet controller connects to the SDRAM as Wishbone master,
through the bus arbitrator in the audio_player device.

The Ethernet controller also connects to the spimaster device as
a Wishbone master, which in turn drives the SPI signals to the ENC424J600
device.

### DAC controller

The DAC controller connects to the SDRAM as Wishbone master, through
the bus arbitrator in the audio_player device.

Internally the DAC controller is actually two state machines.  There
are various signals shared between these state machines, and they
transfer data through the dual-port SRAM contained in the FPGA.

Between the two state machines of the DAC controller there are also
various interconnections that cross the clock domains of the FPGA's
internal clock and the external 16.9 MHz clock.  Because of this
there are various synchronizer circuits used.  At the moment the
design does not pass the Xilinx tools' timing analysis, but works
in practice.


### SDRAM controller

Acts as a Wishbone slave.

### SPI Wishbone Wrapper

Connects to the Wishbone registers as a master, with the registers
acting as a slave.

### SDRAM Wishbone Bus Aribtrator

Connects the Ethernet, DAC, and Raspberry Pi Wishbone masters with the
SDRAM Wishbone slave.  The highest priority is given to the DAC controller
to prevent starvation of the D-to-As, second priority to the Ethernet
controller, and last priority to the Raspberry Pi.


## Data Flow

The Ethernet controller communicates with the ENC424J600.  It reads raw
Ethernet packets from the ENC424J600's SRAM buffer over SPI.  It then
decodes this data into IP fragments and then UDP datagrams.  The 24-bit
audio samples contained in the UDP datagrams is written to the SDRAM
as a circular buffer.  The one 20-bit sample is stored in a 32-bit word
in SDRAM.  The SDRAM controller presents a 32-bit Wishbone bus which
makes this relatively easy to do.

Meanwhile, one state machine in the DAC controller reads audio samples
stored in 32-bit words in the FGPA's dual-port SRAM.  The samples are
stored in 8 regsiters (one per channel) and then clocked out to the 6
D-to-As.  Every time the reader state machine's read pointer crosses
half of the SRAM addresses, it signals the second state machine to
refill that half of the SRAM.

The second state machine waits for the refill signal as mentioned above.
When signaled, it reads 32-bit words from the SDRAM and writes them
to the SRAM.  There is a slightly different algorithm used to initialize
the SRAM so that entire SRAM is filled instead of just half before
returning to the idle state.

Finally, there is a Wishbone bus arbiter in the top-level audio_player
module that arbitrates SDRAM access between the Ethernet and DAC
controllers.  The top-level module also monitors when the SDRAM circular
buffer is empty (using the read and write pointers of the DAC and Ethernet
controllers respectively), generating a signal and a count of how much
buffer space is available for the other state machines to use.

In short, the data flow is Ethernet -> SDRAM -> SRAM -> D to A.

## Justification

Using the SDRAM allows for a large buffer to compensate for any lost
Ethernet packets.  However, an SDRAM controller needs to run refresh
cycles, which adds "arbitrary" delays into read and write cycles.  While
it is possible to design the refresh cycles into the read and write
processes in a way that is predicatable, my design makes no such
assumptions.  Instead, the dual-port SRAM is used as secondary buffer to
remove any delays caused by the SDRAM controller.

The SRAM in itself is not large enough to compensate for Ethernet hiccups,
so both kinds of memory are needed to make the audio player stable.
