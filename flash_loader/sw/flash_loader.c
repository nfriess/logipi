#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <string.h>
#include <fcntl.h>
#include <time.h>

#define FLASH_SIZE (1024*1024)

#define FLASH_SECTOR_SIZE (1<<16)
#define FLASH_PAGE_SIZE (1<<8)

extern int spi_init();
extern void spi_close();
extern int spi_transfer(unsigned char * send_buffer, unsigned char * receive_buffer, unsigned int size);

extern int i2c_disconnect_spi();

int main(int argc, char **argv) {

	int inputFile;
	struct stat bitStat;
	unsigned char spiBuffer[1024];
	unsigned char *bitFileData, *startCfgPtr, *flashMemory;
	unsigned int i, bitFileLen, flashDataLen;
	int ret;
	time_t startTime, currentTime;


	if (argc < 2) {
		fprintf(stderr, "Usage: %s filename.bit\n", argv[0]);
		return 1;
	}

	inputFile = open(argv[1], O_RDONLY);

	if (inputFile < 0) {
		fprintf(stderr, "Error opening file: %s\n", argv[1]);
		return 1;
	}

	if (fstat(inputFile, &bitStat)) {
		fprintf(stderr, "Error getting file size: %s\n", argv[1]);
		close(inputFile);
		return 1;
	}

	bitFileLen = bitStat.st_size;

	if (bitFileLen > FLASH_SIZE) {
		fprintf(stderr, "Bit file too large\n");
		close(inputFile);
		return 1;
	}

	bitFileData = malloc(bitFileLen);
	if (!bitFileData) {
		fprintf(stderr, "malloc error\n");
		close(inputFile);
		return 1;
	}

	if (read(inputFile, bitFileData, bitFileLen) != bitFileLen) {
		fprintf(stderr, "Error while reading file: %s\n", argv[1]);
		close(inputFile);
		return 1;
	}

	close(inputFile);

	printf("Bit file size: %i bytes\n", bitFileLen);


	startCfgPtr = (unsigned char *)0xFFFFFFFF;

	// Search for sych word
	for (i = 0; i < bitFileLen-4; i++) {

		if (bitFileData[i] == 0xAA && bitFileData[i+1] == 0x99 && bitFileData[i+2] == 0x55 && bitFileData[i+3] == 0x66) {
			startCfgPtr = bitFileData + i;
			break;
		}

	}

	if (startCfgPtr == (unsigned char *)0xFFFFFFFF) {
		fprintf(stderr, "Couldn't find sync word in bit file\n");
		return 1;
	}

	printf("Sync word found at 0x%x\n", (startCfgPtr-bitFileData));

	// Start with 16 bytes of 0xFF then the rest of the bit file

	flashDataLen = (bitFileLen - (startCfgPtr-bitFileData)) + 16;

	flashMemory = malloc(flashDataLen);
	if (!flashMemory) {
		fprintf(stderr, "malloc error\n");
		return 1;
	}

	memset(flashMemory, 0xFF, 16);
	memcpy(flashMemory+16, startCfgPtr, flashDataLen - 16);

	free(bitFileData);


	ret = system("/usr/bin/logi_loader spibridge.bit");
	if (ret != 1<<8) {
		fprintf(stderr, "Error loading spibridge.bit, return code: %d\n", ret);
		return 1;
	}

	if (i2c_disconnect_spi())
		return 1;

	if (spi_init())
		return 1;

	memset(spiBuffer, 0, sizeof(spiBuffer));
	spiBuffer[0] = 0x9F; // RDID

	if (spi_transfer(spiBuffer, spiBuffer, 4)) {
		fprintf(stderr, "Error communicating with flash\n");
		spi_close();
		return 1;
	}

	if (spiBuffer[1] != 0x01 || spiBuffer[2] != 0x02 || spiBuffer[3] != 0x15) {
		fprintf(stderr, "Flash chip is not responding %02X %02X %02X\n", spiBuffer[1], spiBuffer[2], spiBuffer[3]);
		spi_close();
		return 1;
	}

/*
	spiBuffer[0] = 0x06; // WREN (write enable)

	if (spi_transfer(spiBuffer, spiBuffer, 1)) {
		fprintf(stderr, "Error communicating with flash\n");
		spi_close();
		return 1;
	}
*/

	printf("Erase old data...\n");

	// Erase all sectors that we are about to use

	// We add 64K to data len so that we make sure to erase
	// the last sector too.
	for (i = 0; i < (flashDataLen+FLASH_SECTOR_SIZE); i += FLASH_SECTOR_SIZE) {

		// WE latch is disabled after every sector erase

		spiBuffer[0] = 0x06; // WREN (write enable)

		if (spi_transfer(spiBuffer, spiBuffer, 1)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		spiBuffer[0] = 0xD8; // SE (sector erase)

		spiBuffer[1] = (i >> 16) & 0xFF; // Address
//		spiBuffer[2] = (i >> 8) & 0xFF;
//		spiBuffer[3] = i & 0xFF;
		spiBuffer[2] = 0x00;
		spiBuffer[3] = 0x00;

		if (spi_transfer(spiBuffer, spiBuffer, 4)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		time(&startTime);

		do {

			spiBuffer[0] = 0x05; // RDSR (read status)

			if (spi_transfer(spiBuffer, spiBuffer, 2)) {
				fprintf(stderr, "Error communicating with flash\n");
				spi_close();
				return 1;
			}

			time(&currentTime);
			if (currentTime - startTime > 5) {
				fprintf(stderr, "Flash erase took too long\n");
				spi_close();
				return 1;
			}

		} while (spiBuffer[1] & 0x01); // WIP (write in progres)

	} // sector erase


	printf("Write new data...\n");

	// Write data one page at a time

	for (i = 0; i < flashDataLen; i += FLASH_PAGE_SIZE) {

		// WE latch is disabled after every page program

		spiBuffer[0] = 0x06; // WREN (write enable)

		if (spi_transfer(spiBuffer, spiBuffer, 1)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		spiBuffer[0] = 0x02; // PP (page program)

		spiBuffer[1] = (i >> 16) & 0xFF; // Address
		spiBuffer[2] = (i >> 8) & 0xFF;
		spiBuffer[3] = 0x00;

		memcpy(spiBuffer+4, flashMemory+i, FLASH_PAGE_SIZE);

		if (spi_transfer(spiBuffer, spiBuffer, 4 + FLASH_PAGE_SIZE)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		time(&startTime);

		do {

			spiBuffer[0] = 0x05; // RDSR (read status)

			if (spi_transfer(spiBuffer, spiBuffer, 2)) {
				fprintf(stderr, "Error communicating with flash\n");
				spi_close();
				return 1;
			}

			time(&currentTime);
			if (currentTime - startTime > 5) {
				fprintf(stderr, "Flash write took too long\n");
				spi_close();
				return 1;
			}

		} while (spiBuffer[1] & 0x01); // WIP (write in progres)
	}

	// Last page

	if (flashDataLen - i > 0) {

		unsigned int remain = flashDataLen - i + FLASH_PAGE_SIZE;

		// WE latch is disabled after every page program

		spiBuffer[0] = 0x06; // WREN (write enable)

		if (spi_transfer(spiBuffer, spiBuffer, 1)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		spiBuffer[0] = 0x02; // PP (page program)

		spiBuffer[1] = (i >> 16) & 0xFF; // Address
		spiBuffer[2] = (i >> 8) & 0xFF;
		spiBuffer[3] = 0x00;

		memcpy(spiBuffer+4, flashMemory + i, remain);

		if (spi_transfer(spiBuffer, spiBuffer, 4 + remain)) {
			fprintf(stderr, "Error communicating with flash\n");
			spi_close();
			return 1;
		}

		time(&startTime);

		do {

			spiBuffer[0] = 0x05; // RDSR (read status)

			if (spi_transfer(spiBuffer, spiBuffer, 2)) {
				fprintf(stderr, "Error communicating with flash\n");
				spi_close();
				return 1;
			}

			time(&currentTime);
			if (currentTime - startTime > 5) {
				fprintf(stderr, "Flash write took too long\n");
				spi_close();
				return 1;
			}

		} while (spiBuffer[1] & 0x01); // WIP (write in progres)

	} // Last page

/*
	spiBuffer[0] = 0x04; // WRDI (write disable)

	if (spi_transfer(spiBuffer, spiBuffer, 1)) {
		fprintf(stderr, "Error communicating with flash\n");
		spi_close();
		return 1;
	}
*/

	printf("Done!\n");

	spi_close();

	return 0;

}
