## SW0 (Switch 1)

Set to ON to use an external audio clock, or OFF to generate
a (very close) internal audio clock.

## LED0

Will light up when the audio output is in MUTE.

## LED1

Will light up when one or more interrupts are missed.  This can be used to
see if the Raspberry Pi is falling a behind further than expected, even if
it is not quite getting to the point of completely emptying the bufefer.

## External clock

This is connected to the Arduino port on top of the Logi-Pi,
port D4.  This is also the same as PMOD1.7.

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

## Raspberry Pi Control Connections

The I2C-1 interface on the Raspberry Pi is used to access control registers on
the Logi-Pi.  In Linux this is /dev/i2c-1.  The register definitions are in
the pi_control_.md file.

The GPIO pin 27 (pin 13 on the Pi's header) is used as an interrupt pin to
signal when more data can be sent to the Logi-Pi.

## Raspberry Pi Data Connection

The SPI interface at /dev/spidev0.0 is used to transfer the audio data from
the Raspberry Pi to the Logi-Pi.  The protocol used is described in the
pi_data.md file.
