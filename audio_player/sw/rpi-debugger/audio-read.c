#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <time.h>
#include <signal.h>
#include <linux/spi/spidev.h>
#include "wishbone_wrapper.h"


static unsigned char buffer[1024];
static unsigned char randomdata[1024*1024];


extern int spi_init();
extern void spi_close();

extern unsigned long spi_speed;
extern int spi_fd;

int main(int argc, char ** argv){

	int fd, randptr, i;

	i = 0; // address

	if (argc > 1) {
		i = strtoul(argv[1], NULL, 16);
	}

	fd = open("randdata.bin", O_RDONLY, 0);
	if (fd < 0) {
		fprintf(stderr, "Error opening randata.bin");
		exit(1);
	}
	read(fd, randomdata, 1024*1024);
	close(fd);

	spi_init();

	wishbone_read((unsigned char *)buffer, 2, 0x0000);

	if (buffer[1] != 0xde || buffer[0] != 0xad) {
		fprintf(stderr, "Invalid ID: 0x%02x%02x.  Did you load the FPGA?\n", buffer[1], buffer[0]);
		spi_close();
		exit(1);
	}

	// Reset
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

//	randptr = 0;

	printf("%04x: ", i);

	for ( ; i < 1 << 24; i++) {

		// Address
		buffer[1] = 0;
		buffer[0] = (i >> 16) & 0xFF;

		wishbone_write((unsigned char *)buffer, 2, 0x0002);

		buffer[1] = (i >> 8) & 0xFF;
		buffer[0] = i & 0xFF;

		wishbone_write((unsigned char *)buffer, 2, 0x0003);


		// Read
		buffer[1] = 0;
		buffer[0] = 1;

		wishbone_write((unsigned char *)buffer, 2, 0x0004);
		usleep(10);

		// Reset
		buffer[1] = 0;
		buffer[0] = 0;

		wishbone_write((unsigned char *)buffer, 2, 0x0004);

		wishbone_read((unsigned char *)buffer, 2, 0x0001);

		printf("%02x%02x ", buffer[1], buffer[0]);
		if ((i % 16) == 15) {
			printf("\n%04x: ", i+1);
			fflush(stdout);
		}

/*		if ((buffer[1] != randomdata[randptr * 2]) ||
			buffer[0] != randomdata[randptr * 2 + 1]) {

			printf("Data mismatch at address 0x%04x, 0x%02x%02x vs 0x%02x%02x\n", i,
					buffer[1], buffer[0], randomdata[randptr * 2], randomdata[randptr * 2 + 1]);
			break;
		}

		randptr++;
		if (randptr > 512*1024-7) {
			randptr = 0;
		}

		if ((i % 1024) == 0) {
			printf("%dK\n", (i/1024));
			fflush(stdout);
		}
*/
	}


	spi_close();
	return 0;

}

