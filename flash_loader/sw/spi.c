#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/spi/spidev.h>

int spi_fd ;
unsigned int fifo_size ;
static const char * device = "/dev/spidev0.0";
static unsigned int mode = 0 ;
static unsigned int bits = 8 ;
unsigned long spi_speed = 16000000UL ;
static unsigned int delay = 0;

// Flash chip should go up to 50MHz, but it only
// seems stable up to 16MHz or so.


// SPI routines borrowed from logipi_loader and logipi_wishbone projects

int spi_init(void){
	int ret ;
	spi_fd = open(device, O_RDWR);
	if (spi_fd < 0){
		perror("Error while opening SPI device");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_WR_MODE, &mode);
	if (ret == -1){
		perror("Can't set SPI mode");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_MODE, &mode);
	if (ret == -1){
		perror("Can't get SPI mode");
		return -1 ;
	}

	/*
	 * bits per word
	 */
	ret = ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
	if (ret == -1){
		perror("Can't set bits per word");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
	if (ret == -1){
		perror("Can't get bits per word");
		return -1 ;
	}

	/*
	 * max speed hz
	 */
	ret = ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &spi_speed);
	if (ret == -1){
		perror("Can't set max speed hz");
		return -1 ;
	}

	ret = ioctl(spi_fd, SPI_IOC_RD_MAX_SPEED_HZ, &spi_speed);
	if (ret == -1){
		perror("Can't get max speed hz");
		return -1 ;
	}

	return 0;
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
		perror("Can't send spi message");
		return -1 ;
	}
	return 0;
}

void spi_close(void){
	close(spi_fd);
}
