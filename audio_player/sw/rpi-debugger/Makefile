CC = gcc


all: audio printstate sendpattern audio-print

clean:
	rm -f *.a *.o audio printstate

gpio.o: gpio.c
	$(CC) -c gpio.c

wishbone_wrapper.o: wishbone_wrapper.c
	$(CC) -c wishbone_wrapper.c

audio : audio.c wishbone_wrapper.o gpio.o
	$(CC) -o $@ audio.c wishbone_wrapper.o gpio.o

printstate : printstate.c wishbone_wrapper.o gpio.o
	$(CC) -o $@ printstate.c wishbone_wrapper.o gpio.o

sendpattern : sendpattern.c wishbone_wrapper.o gpio.o
	$(CC) -o $@ sendpattern.c wishbone_wrapper.o gpio.o

audio-print : audio-print.c wishbone_wrapper.o gpio.o
	$(CC) -o $@ audio-print.c wishbone_wrapper.o gpio.o
