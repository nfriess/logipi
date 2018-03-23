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
#include <sys/socket.h>
#include <netinet/in.h>
#include "wishbone_wrapper.h"


static unsigned char buffer[1024];


extern int spi_init();
extern void spi_close();

int main(int argc, char ** argv){

	spi_init();

	wishbone_read((unsigned char *)buffer, 2, 0x0000);

	if (buffer[1] != 0xde || buffer[0] != 0xad) {
		fprintf(stderr, "Invalid ID: 0x%02x%02x.  Did you load the FPGA?\n", buffer[1], buffer[0]);
		spi_close();
		exit(1);
	}

	fprintf(stderr, "Ethernet\n--------\n");
	wishbone_read((unsigned char *)buffer, 2, 0x0005);
	fprintf(stderr, "  State: 0x%02x%02x\n", buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x0007);
	wishbone_read(((unsigned char *)buffer)+2, 2, 0x0006);
	fprintf(stderr, "  Complete ptr: 0x%02x%02x%02x%02x\n", buffer[3], buffer[2], buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x00015);
	fprintf(stderr, "  Next sequence: 0x%02x%02x\n", buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x00017);
	fprintf(stderr, "  IP Ident: 0x%02x%02x\n", buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x00018);
	fprintf(stderr, "  IP Fragment Offset: 0x%02x%02x\n", buffer[1], buffer[0]);

	fprintf(stderr, "\nDAC\n---\n");
	wishbone_read((unsigned char *)buffer, 2, 0x0008);

	fprintf(stderr, "  State: %s%sstate: 0x%02x  empty count: 0x%02x\n",
		(buffer[1] & 0x80) ? "sdram_empty " : "",
		(buffer[1] & 0x40) ? "sram_empty " : "",
		(buffer[1]) & 0x0F, buffer[0] & 0xFF);

	wishbone_read((unsigned char *)buffer, 2, 0x000a);
	wishbone_read(((unsigned char *)buffer)+2, 2, 0x00009);
	fprintf(stderr, "  SDRAM Read ptr: 0x%02x%02x%02x%02x\n", buffer[3], buffer[2], buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x000d);
	wishbone_read(((unsigned char *)buffer)+2, 2, 0x0000c);
	fprintf(stderr, "  Window size: 0x%02x%02x%02x%02x\n", buffer[3], buffer[2], buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x00013);
	fprintf(stderr, "  SRAM read addr: 0x%02x%02x\n", buffer[1], buffer[0]);

	wishbone_read((unsigned char *)buffer, 2, 0x00014);
	fprintf(stderr, "  SRAM write addr: 0x%02x%02x\n", buffer[1], buffer[0]);

	fprintf(stderr, "\nSDRAM\n-----\n");
	wishbone_read((unsigned char *)buffer, 2, 0x0000b);
	fprintf(stderr, "  Bus state: %s%s%s%s%s%s 0x%02x\n",
		(buffer[1] & 0x80) ? "dac " : "",
		(buffer[1] & 0x40) ? "eth " : "",
		(buffer[1] & 0x20) ? "rpi " : "",
		(buffer[1] & 0x10) ? "stall " : "",
		(buffer[1] & 0x08) ? "stb " : "",
		(buffer[1] & 0x04) ? "ack " : "",
		buffer[0]);

	fprintf(stderr, "\n");

	spi_close();
	return 0;

}
