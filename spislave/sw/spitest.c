/*

SPI test program

This program will test spislave.vhd, assuming it is
connected to a 32K SRAM buffer.


Copyright (C) 2017  Nathan Friess

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
ERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>
#include <time.h>

// SPI routines borrowed from logipi_loader

static int spi_fd ;
static unsigned int mode = 0 ;
static unsigned int bits = 8 ;
unsigned long spi_speed = 3300000UL ;
static unsigned int delay = 0;


int spi_transfer(unsigned char * send_buffer, unsigned char * receive_buffer, unsigned int size)
{
        int ret ;
        struct spi_ioc_transfer tr;

	memset(&tr, 0, sizeof(struct spi_ioc_transfer));

        tr.tx_buf = (__u32)send_buffer;
        tr.rx_buf = (__u32)receive_buffer;
        tr.len = size;
        tr.delay_usecs = delay;
        tr.speed_hz = spi_speed;
        tr.bits_per_word = bits;

        ret = ioctl(spi_fd, SPI_IOC_MESSAGE(1), &tr);
        if (ret < 1){
                printf("can't send spi message  \n");
                return -1 ;
        }
        return 0;
}

int main() {

	int i, j, r;
	unsigned char spi_out[1024], spi_in[1024];

	spi_fd = open("/dev/spidev0.0", O_RDWR);
	if (spi_fd < 0) {
		printf("could not open SPI device\n");
		return -1;
	}
	if (ioctl(spi_fd, SPI_IOC_WR_MODE, &mode) < 0) {
		printf("Can't set SPI WR mode\n");
		close(spi_fd);
		return -1;
	}
	if (ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits) < 0) {
		printf("Can't set SPI WR bit size\n");
		close(spi_fd);
		return -1;
	}
	if (ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &spi_speed) < 0) {
		printf("Can't set SPI WR speed\n");
		close(spi_fd);
		return -1;
	}


	srand(time(NULL));
	r = rand();

	printf("Writing data...\n");

// Writing one word at a time...
/*	for (i = 0; i < (1<<15); i++) {

		// Addr, top bit = 1 for write
		spi_out[0] = (unsigned char) (((i >> 8) & 0xFF) | 0x80);
		spi_out[1] = (unsigned char) (i & 0xFF);
		// Data
		spi_out[2] = (unsigned char)(((i >> 8) ^ (r >> 8)) & 0xFF);
		spi_out[3] = (unsigned char)((i ^ r) & 0xFF);

		spi_transfer(spi_out, spi_in, 4);

	}
*/

	// Writing 1K blocks at a time
	for (i = 0; i < (1<<15); ) {

		// Addr, top bit = 1 for write
		spi_out[0] = (unsigned char) (((i >> 8) & 0xFF) | 0x80);
		spi_out[1] = (unsigned char) (i & 0xFF);
		// Data
		for (j = 2; j < 1024 && i < (1<<15); j+=2, i++) {
			spi_out[j] = (unsigned char)(((i >> 8) ^ (r >> 8)) & 0xFF);
			spi_out[j+1] = (unsigned char)((i ^ r) & 0xFF);
		}

		spi_transfer(spi_out, spi_in, j);

	}

	printf("Reading back data...\n");

	for (i = 0; i < (1<<15); i++) {

		// Addr, top bit = 0 for read
		spi_out[0] = (unsigned char) ((i >> 8) & 0x7F);
		spi_out[1] = (unsigned char) (i & 0xFF);

		spi_transfer(spi_out, spi_in, 4);

		if ((unsigned char)(((i >> 8) ^ (r >> 8)) & 0xFF) != spi_in[2] ||
		    (unsigned char)((i ^ r) & 0xFF) != spi_in[3]) {
			printf("Mismatch at 0x%04x: 0x%04x vs 0x%02x%02x\n", i, (i ^ r) & 0xFFFF, spi_in[2], spi_in[3]);
		}

	}

	printf("Done\n");

	close(spi_fd);

	return 0;

}
