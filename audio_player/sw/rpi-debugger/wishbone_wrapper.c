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
#include <linux/types.h>
#include <linux/spi/spidev.h>


#define WR0(a, i)	((a >> 14) & 0x0FF)
#define WR1(a, i)	((a >> 6) & 0x0FF)
#define WR2(a, i)	(((a << 2) & 0xFC) | (i << 1))

#define RD0(a, i)	((a >> 14) & 0x0FF)
#define RD1(a, i)	((a >> 6) & 0x0FF)
#define RD2(a, i)	(((a << 2) & 0xFC) | 0x01 | (i << 1))



int spi_fd ;
unsigned int fifo_size ;
static const char * device = "/dev/spidev0.0";
static unsigned int mode = 0 ;
static unsigned int bits = 8 ;
unsigned long spi_speed = 32000000UL ;
static unsigned int delay = 0;

#define COM_BUFFER_SIZE 32768
static unsigned char com_buffer [COM_BUFFER_SIZE] ;


void spi_close(void) ;
int spi_init(void) ;
int spi_transfer(unsigned char * send_buffer, unsigned char * receive_buffer, unsigned int size);
int logipi_write(unsigned int add, unsigned char * data, unsigned int size, unsigned char inc);
int logipi_read(unsigned int add, unsigned char * data, unsigned int size, unsigned char inc);

int spi_init(void){
	int ret ;
	spi_fd = open(device, O_RDWR);
	if (spi_fd < 0){
		printf("can't open device\n");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_WR_MODE, &mode);
	if (ret == -1){
		printf("can't set spi mode \n");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_MODE, &mode);
	if (ret == -1){
		printf("can't get spi mode \n ");
		return -1 ;
	}

	/*
	 * bits per word
	 */
	ret = ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
	if (ret == -1){
		printf("can't set bits per word \n");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
	if (ret == -1){
		printf("can't get bits per word \n");
		return -1 ;
	}

	/*
	 * max speed hz
	 */
	ret = ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &spi_speed);
	if (ret == -1){
		printf("can't set max speed hz \n");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_MAX_SPEED_HZ, &spi_speed);
	if (ret == -1){
		printf("can't get max speed hz \n");
		return -1 ;
	}

	return 1;
}


int spi_transfer(unsigned char * send_buffer, unsigned char * receive_buffer, unsigned int size)
{
	int ret ;
	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)send_buffer,
		.rx_buf = (unsigned long)receive_buffer,
		.len = size,
		.delay_usecs = delay,
		.speed_hz = spi_speed,
		.bits_per_word = bits,
	};

	ret = ioctl(spi_fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1){
		printf("can't send spi message  \n");
		return -1 ;	
	}
	return 0;
}

int logipi_write(unsigned int add, unsigned char * data, unsigned int size, unsigned char inc){
	com_buffer[0] = WR0(add, inc) ;
	com_buffer[1] = WR1(add, inc) ;
	com_buffer[2] = WR2(add, inc) ;
	memcpy(&com_buffer[3], data, size);
	return spi_transfer(com_buffer, com_buffer , (size + 3));
}


int logipi_read(unsigned int add, unsigned char * data, unsigned int size, unsigned char inc){
	int ret ;	
	com_buffer[0] = RD0(add, inc) ;
	com_buffer[1] = RD1(add, inc) ;
	com_buffer[2] = RD2(add, inc) ;
	ret = spi_transfer(com_buffer, com_buffer , (size + 3));
	memcpy(data, &com_buffer[3], size);
	return ret ;
}


void spi_close(void){
	close(spi_fd);
}


unsigned int wishbone_write(unsigned char * buffer, unsigned int length, unsigned int address){
	unsigned int tr_size = 0, count = 0 ;
	if(spi_fd == 0){
		spi_init();
	}
	while(count < length){
                tr_size = (length-count) < (COM_BUFFER_SIZE-3) ? (length-count) : (COM_BUFFER_SIZE-3) ;
		if(logipi_write((address+count), &buffer[count], tr_size, 1) < 0) return 0;
		count = count + tr_size ;
        }

	return count ;
}
unsigned int wishbone_read(unsigned char * buffer, unsigned int length, unsigned int address){
	unsigned int tr_size = 0, count = 0 ;
	if(spi_fd == 0){
		spi_init();
	}
	while(count < length){
		tr_size = (length-count) < (COM_BUFFER_SIZE-3) ? (length-count) : (COM_BUFFER_SIZE-3) ;
		if(logipi_read((address+count), &buffer[count], tr_size, 1) < 0) return 0 ;
		count = count + tr_size ;
	}
	return count ;
}


