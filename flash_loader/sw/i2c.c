#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <error.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

// I2C routines borrowed from logipi_loader

int i2c_disconnect_spi() {

	int i2c_fd;
	unsigned char buffer[4];

	// logi_loader leaves fpga/flash SPI pins connected to Pi
	// so we need to disconnect them now

	i2c_fd = open("/dev/i2c-1", O_RDWR);
	if (i2c_fd < 0) {
		perror("Could not open I2C device");
		close(i2c_fd);
		return 1;
	}
	if (ioctl(i2c_fd, I2C_SLAVE, 0x20) < 0) {
		perror("I2C ioctl failed");
		close(i2c_fd);
		return 1;
	}

	buffer[0] = 0x00; // Address of data register

	if (write(i2c_fd, buffer, 1) != 1) {
		perror("I2C write failed");
		close(i2c_fd);
		return 1;
	}
	if (read(i2c_fd, buffer+1, 1) != 1) {
		perror("I2C read failed");
		close(i2c_fd);
		return 1;
	}

	buffer[1] |= 0x10; // OE bit that controls SPI

	if (write(i2c_fd, buffer, 2) != 2) {
		perror("I2C write failed");
		close(i2c_fd);
		return 1;
	}

	close(i2c_fd);

	return 0;

}
