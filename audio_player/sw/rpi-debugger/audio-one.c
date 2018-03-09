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

	int randptr, i;

	spi_init();

	wishbone_read((unsigned char *)buffer, 2, 0x0000);

	if (buffer[1] != 0xde || buffer[0] != 0xad) {
		fprintf(stderr, "Invalid ID: 0x%02x%02x.  Did you load the FPGA?\n", buffer[1], buffer[0]);
		spi_close();
		exit(1);
	}


/*
	// Reset
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Address
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0002);

	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0003);

	// Data
	buffer[1] = 0xBE;
	buffer[0] = 0xEF;

	wishbone_write((unsigned char *)buffer, 2, 0x0001);

	// Write
	buffer[1] = 0;
	buffer[0] = 3;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Reset
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Address
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0002);

	buffer[1] = 0;
	buffer[0] = 3;

	wishbone_write((unsigned char *)buffer, 2, 0x0003);

	// Data
	buffer[1] = 0xF0;
	buffer[0] = 0x0D;

	wishbone_write((unsigned char *)buffer, 2, 0x0001);

	// Write
	buffer[1] = 0;
	buffer[0] = 3;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);
*/

	for (i = 0; i < 256; i++) {

	// Reset
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Address
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0002);

	buffer[1] = 0;
	buffer[0] = i;

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
	fprintf(stderr, "0x%02x: 0x%02x%02x\n", i, buffer[1], buffer[0]);

	}


	// Reset
	buffer[1] = 0;
	buffer[0] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Address
	buffer[1] = 0;
	buffer[0] = 1;

	wishbone_write((unsigned char *)buffer, 2, 0x0002);

	buffer[1] = 0;
	buffer[0] = 1;

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
	fprintf(stderr, "Read data 0x%02x%02x\n", buffer[0], buffer[1]);




/*
	// Address
	buffer[0] = 0;
	buffer[1] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0003);

	// Read
	buffer[0] = 1;
	buffer[1] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	sleep(1);

	// Reset
	buffer[0] = 0;
	buffer[1] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Data
	wishbone_read((unsigned char *)buffer, 2, 0x0001);

	fprintf(stderr, "Read data 0x%02x%02x\n", buffer[0], buffer[1]);




	// Address
	buffer[0] = 0;
	buffer[1] = 10;

	wishbone_write((unsigned char *)buffer, 2, 0x0003);

	// Read
	buffer[0] = 1;
	buffer[1] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	sleep(1);

	// Reset
	buffer[0] = 0;
	buffer[1] = 0;

	wishbone_write((unsigned char *)buffer, 2, 0x0004);

	// Data
	wishbone_read((unsigned char *)buffer, 2, 0x0001);

	fprintf(stderr, "Read data 0x%02x%02x\n", buffer[0], buffer[1]);


*/









	spi_close();
	return 0;

}

