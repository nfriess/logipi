## SW0 (Switch 1)

Set to ON to use an external audio clock, or OFF to generate
a (very close) internal audio clock.

## SW1 (Switch 2)

Set to ON to bypass waiting for a DHCP-assigned IP address
and immediately pick a link-local IP address.

## LED0

Will light up when the audio output is in MUTE.

## LED1

Will light up when the Logi-Pi has an IP address assigned and
is sending status packets to the host PC.  When initializing,
if the PmodNIC100 is not responding to commands then this LED
will blink steadily until the FPGA is reset.

## PmodNIC100

This is connected to PMOD1.

## External clock

This is connected to the Arduino port on top of the Logi-Pi,
port D4.  This is also the same as PMOD1.7, but since the
PmodNIC100 is using that port, it is not easy to access unless
you solder an extra lead to that connector.

## D-to-A

As is right now, the D-to-As are driven by single-ended signals.
They could also be driven as 3.3V differential signals, which
is why the data lines are split among two PMOD connectors.

These signals were chosen arbitrarily during various tests with
other hardware.  There is no particular reason to the inverted
bit and word clocks, for example.

PMOD4:

* Bit 0: Word Clock
* Bit 1: Bit Clock
* Bit 2: Left treble data
* Bit 3: Right treble data

PMOD3:

* Bit 0: Inverted Word Clock
* Bit 1: Inverted Bit Clock
* Bit 4: Left mid-range data
* Bit 5: Right mid-range data
* Bit 6: Left bass data
* Bit 7: Right bass data

## Raspberry Pi

The SPI interface is available for the Raspberry PI to read
and write debug registers.
