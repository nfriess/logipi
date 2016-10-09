# Building the Code

Build the VHDL project in hdl/

Build the C# project in sw/

Optional: Connect the Logi-Pi to a Raspberry Pi.  Use my
flash_loader project to write the .bit file for for the FPGA
into flash memory.  This will allow the audio player to run
without a Raspberry Pi.  Otherwise you can just load the
.bit using the standard Logi-Pi tools every time you power
up the board.

# Running the Code

## Connections

Connect a Digilent PmodNIC100 to the Logi-Pi's PMOD1 port.

Connect the 6 D-to-As to the various lines on the PMOD3 and
PMOD4 ports.

You can connect the Ethernet cable to the PmodNIC either
before or after powering on the Logi-Pi.

## Start-up

If using an external 16.9MHz clock, set SW0 (switch 1) to ON
and connect the clock to D4 of the upper Arduino plug.

If you are using the Logi-Pi standalone, then disconnect
the Raspberry Pi and connect a 5V micro-USB power supply to
the Logi-Pi board.

Otherwise, the Logi-Pi can be powered from the Raspberry Pi
and you can load the .bit file from the Raspberry Pi now.

## Initialization

At first, LED0 should be lit up, indicating that the audio
output is currently in a MUTE state.

The LEDs on the PmodNIC indicate the Ethernet connection
status.

After the device has obtained an IP either by DHCP or by
choosing a link-local address, LED1 will light up.  (It
takes quite a while for DHCP time timeout so be patient.)

## Playback

Run the C# program in Windows.  You should see the device's
IP address appear and the Window size being large, indicating
that the device's SDRAM buffer is empty.

Click Play WAV and select a WAV file to play.  You can use
STOP, Mute On/Off, and Pause On/Off during playback.  The
test buttons generate test signals for debugging only and
should never be used with real speakers.

# Troubleshooting

## No route to host

The device sends status packets to the host PC using IP
broadcasts.  However, the host sends data to the Logi-Pi
using its IP address directly.  This means that the C#
program can see status packets, but that does not mean that
it can send to that IP address.

If, for some reason, the host PC and the Logi-Pi have IP
addresses in different subnets, attempting to start playing
a WAV file will result in an error like "No route to host".

To resolve this, make sure that a DHCP server is accessible
to both the host PC and the Logi-Pi, or that Windows is
configured to select IPs from the link-local range like the
Logi-Pi will.  This is the default configuration for Windows
networking.

## No sound output from D-to-As

Did you set the SW0 switch to use an internal or external
16.9MHz clock?  If external, is the clock connected to D4?

Try using the internal clock first to troubleshoot this.

If data is transferring over the network correctly, then you
will see the Window size decrease at first and then hover
around a low number.  The Outstanding and Queue Len should
be low and relatively steady.  If so, then it may be that
you have not connected the D-to-A signals correctly.

Finally, when playback starts MUTE and PAUSE should be
automatically de-asserted by the C# program, but you may
want to check by clicking OFF on both buttons.

LED0 should not be lit up during playback.  If it does light
up unexpectedly, then the SDRAM buffer has become empty and
no data is being recieved over the network.


## Pauses in playback

If the audio plays but has gaps, then this is likely that
there are network connectivity issues causing too many
Ethernet packets to be lost.  Check that you have good
cables and any networking equipment in between (like a
switch, if you use one).

If the issue is intermittent, you may be able to reduce
the chance by increasing the SDRAM buffer size in the VHDL
(there are multiple places where you need to do this).
There is more than enough memory available in the SDRAM to
spare.
