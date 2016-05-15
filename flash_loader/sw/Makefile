
all: flash_loader flash_read

.PHONY: clean
clean:
	rm *.o flash_loader flash_read

flash_loader: flash_loader.o i2c.o spi.o
	gcc -Wall -o $@ $^

flash_read: flash_read.o i2c.o spi.o
	gcc -Wall -o $@ $^

%.o: %.c
	gcc -c -Wall $<
