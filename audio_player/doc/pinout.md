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

* Bit 0: Word Clock (Latch Enable)
* Bit 1: Bit Clock
* Bit 4: Mute (no data being output)
* Bit 5: User Signal
* Bit 6: Idle Signal
* Bit 7: 0 when audio clk is not active

PMOD3:

* Bit 0: Left woofer data
* Bit 1: Right woofer data
* Bit 2: Left low mid-range data
* Bit 3: Right low mid-range data
* Bit 4: Left high mid-range data
* Bit 5: Right high mid-range data
* Bit 6: Left tweeter data
* Bit 7: Right tweeter data

## Raspberry Pi

The SPI interface is available for the Raspberry PI to read
and write debug registers.
