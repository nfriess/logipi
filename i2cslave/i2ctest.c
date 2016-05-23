/*

I2C test program

This program will test i2cslave.vhd, assuming it is
connected to a 32K SRAM buffer.


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
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

#define I2C_DEVICE_ADDR 0x60

// I2C routines borrowed from logipi_loader

int main() {

	int i2c_fd, i;
	unsigned char i2c_out[128], i2c_in[128];


	i2c_fd = open("/dev/i2c-1", O_RDWR);
	if (i2c_fd < 0) {
		printf("could not open I2C device\n");
		close(i2c_fd);
		return -1 ;
	}
	if (ioctl(i2c_fd, I2C_SLAVE, I2C_DEVICE_ADDR) < 0){
		printf("I2C communication error ! \n");
		close(i2c_fd);
		return -1 ;
	}

	printf("Writing data...\n");

	for (i = 0; i < (1<<15); i++) {

		// Addr
		i2c_out[0] = (unsigned char) ((i >> 8) & 0xFF);
		i2c_out[1] = (unsigned char) (i & 0xFF);
		// Data
		i2c_out[2] = (unsigned char)(((i >> 8) ^ 0xDE) & 0xFF);
		i2c_out[3] = (unsigned char)((i ^ 0xAD) & 0xFF);

		write(i2c_fd, i2c_out, 4);

	}

	printf("Reading back data...\n");

	for (i = 0; i < (1<<15); i++) {

		// Addr
		i2c_out[0] = (unsigned char) ((i >> 8) & 0xFF);
		i2c_out[1] = (unsigned char) (i & 0xFF);

		write(i2c_fd, i2c_out, 2);

		i2c_in[0] = 0;
		i2c_in[1] = 0;

		read(i2c_fd, i2c_in, 2);

		if ((unsigned char)(((i >> 8) ^ 0xDE) & 0xFF) != i2c_in[0] ||
		    (unsigned char)((i ^ 0xAD) & 0xFF) != i2c_in[1]) {
			printf("Mismatch at 0x%04x: 0x%04x vs 0x%02x%02x\n", i, i ^ 0xDEAD, i2c_in[0], i2c_in[1]);
			break;
		}

	}

	printf("Done\n");

	close(i2c_fd);

	return 0;

}
