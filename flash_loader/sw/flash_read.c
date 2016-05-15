#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
//#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>

#define FLASH_SIZE (1024*1024*32)

extern int spi_init();
extern void spi_close();
extern int spi_transfer(unsigned char * send_buffer, unsigned char * receive_buffer, unsigned int size);

extern int i2c_disconnect_spi();

int main(int argc, char **argv) {

	int outputFile;
	unsigned char spiBuffer[1024];
	unsigned int i, flashDataLen;
	int ret;

	if (argc < 2) {
		fprintf(stderr, "Usage: %s filename.bin [size_to_read]\n", argv[0]);
		return 1;
	}

	flashDataLen = FLASH_SIZE;

	if (argc == 3) {
		flashDataLen = atoi(argv[2]);
		if (flashDataLen < 1 || flashDataLen > FLASH_SIZE) {
			fprintf(stderr, "Bad number of bytes: %s\n", argv[2]);
			return 1;
		}
	}

	outputFile = open(argv[1], O_WRONLY|O_CREAT|O_EXCL, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);

	if (outputFile < 0) {
		perror("Error creating output file");
		return 1;
	}

	ret = system("/usr/bin/logi_loader spibridge.bit");
	if (ret != 1<<8) {
		fprintf(stderr, "Error loading spibridge.bit, return code: %d\n", ret);
		close(outputFile);
		return 1;
	}

	if (i2c_disconnect_spi())
		return 1;

	// logi_loader leaves fpga/flash SPI pins connected to Pi
	// so we need to disconnect them now

	if (spi_init()) {
		close(outputFile);
		return 1;
	}

	memset(spiBuffer, 0, sizeof(spiBuffer));
	spiBuffer[0] = 0x9F; // RDID

	if (spi_transfer(spiBuffer, spiBuffer, 4)) {
		fprintf(stderr, "Error communicating with flash\n");
		spi_close();
		close(outputFile);
		return 1;
	}

	if (spiBuffer[1] != 0x01 || spiBuffer[2] != 0x02 || spiBuffer[3] != 0x15) {
		fprintf(stderr, "Flash chip is not responding %02X %02X %02X\n", spiBuffer[1], spiBuffer[2], spiBuffer[3]);
		spi_close();
		close(outputFile);
		return 1;
	}


	// Read data one page at a time

	for (i = 0; i < flashDataLen; i += (1<<8)) {


		spiBuffer[0] = 0x03; // READ

		spiBuffer[1] = (i >> 16) & 0xFF; // Address
		spiBuffer[2] = (i >> 8) & 0xFF;
		spiBuffer[3] = 0x00;

		if (spi_transfer(spiBuffer, spiBuffer, 4 + (1<<8))) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			close(outputFile);
			return 1;
		}

		write(outputFile, spiBuffer+4, 1<<8);

	}

	spi_close();

	// We may have written more than we intended to due to page alignment,
	// so truncate the file to right length
	ftruncate(outputFile, flashDataLen);

	close(outputFile);

	printf("Done!\n");

	return 0;

}
