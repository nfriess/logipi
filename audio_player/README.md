# Hifi Audio Player

A friend of mine has been building Hi-fi audio systems for
a very long time.  Before this project started, his current
system used a custom-designed board around a USB device to
stream audio from a host Windows PC to his custom-built
amplifiers.  Over time the USB device has become too
cumbersome so I have helped design a replacement setup
that will drive his amplifiers using a Logi-PI board.

This project is quite complex so more detailed documentation
is available in the doc directory.

## Architecture

### Hi-fi System

I am not an audiophile, nor do I know the intricacies of
audio amplifier design.  My friend has built some of the
highest quality amplifiers around.

For my part of this system, the only aspects that I need
to know are that there are 6 amplifiers (channels), each
driving a speaker.  The input of an amplifier is an AD1862
D-to-A, which accepts a 20-bit audio.  The Latch Enable
pin is driven by a 44.1 KHz clock, which is divided down
from a standard 16.9344 MHz crystal in the FPGA.

### Host PC

My friend has written his own audio player program in
C# that he currently uses to stream audio to the Hi-fi
system.  The program reads in raw .WAV files containing
2 channel, 16-bit, 44.1 KHz audio.  It then converts this
to the 6-channel, 20-bit format that will be consumed by
the D-to-As.  It then sends this data over USB, to an
FPGA that drives the D-to-As.

The source code for my friend's audio player is not
available here because that belongs to him.  The project
here has a very simple C# program that will drive the
FPGA on the Logi-PI over an Ethernet connection.  He has
then taken the core class that handles all of the logic
for the Ethernet protocol and integrated that into his
audio player program.

## Logi-Pi Board

Everything in between the host PC and D-to-As, and the
core of this project.

Although the Logi-Pi board is often paired with a Raspberry
Pi, the Pi is is actually not used in the final product.
Instead, a Pi is used to program the flash chip on the
Logi-PI board and was used to debug the VHDL by monitoring
various registers defined in the VHDL.

Other key components required for this project are:

* Digilent PmodNIC100, an add-on board designed around the
  Microchip ENC424J600 Ethernet controller.

* An external 16.9344 MHz crystal to drive the FPGA (for
  proper hifi audio).  The FPGA can generate an internal
  clock that is very close to 16.9334 MHz for testing
  purposes.



## License

### External Libraries

Several pieces of code in VHDL and Verilog were borrowed
from external sources.  Those files will have their own
copyright notices and licenses in the file headers.

These include:

* sdram_controller.v - From opencores.org, GPL license.
  Has been modified slightly to interoperate with other
  parts of the VHDL project.

* control_pack.vhd, logi_primitive_pack.vhd, logi_utils_pack.vhd
  logi_wishbone_pack.vhd, logi_wishbone_peripherals_pack.vhd,
  logipi_r1_5.ucf, spi_wishbone_wrapper.vhd, wishbone_register.vhd:
  From the Logi-PI example code.  Modifed in several places.

* dp_sram.vhd - From opencores.org, GPL license.


### New code

Other than the above code, any code produced by me is licensed
as:

**Licensed under the GNU GENERAL PUBLIC LICENSE version 2**

Copyright (C) 2016  Nathan Friess

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

http://www.gnu.org/licenses/old-licenses/gpl-2.0-standalone.html
