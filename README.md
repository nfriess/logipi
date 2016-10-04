# Code for Logipi FPGA board

This project contains various bits of code for the logpi board.
More information on the board can be found at
http://valentfx.com/logi-pi/

## Projects

- **audio_player**: A basic implementation to stream hifi
  audio from a host PC to a logipi that drives 6 D-to-As.

- **flash_loader**: A utility to load .bit files on the flash
  chip, or read data from the flash chip.

- **i2cslave**: An I2C slave device that can communicate with
  the Raspberry Pi, implementing a wishbone master in VHDL.

## License

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
