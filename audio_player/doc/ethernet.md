# Ethernet Controller

## Architecture

The ethernet controller is a large state machine that is responsible for
communicating with the Microchip ENC424J600, decoding ethernet, IP, and
UDP packets, and buffering audio data into the SDRAM circular buffer.

The ethernet controller communicates with the ENC424J600 through the
spimaster device.  spimaster handles the low-level SPI signalling while
presenting a Wishbone-like interface to the ethernet controller, allowing
it to write up to 4 bytes and read up 4 bytes on the SPI bus per cycle.

There is also a synchronizer circuit for the incoming ethernet interrupt
signal.

There are two other important aspects to the ethernet controller's
design.  The first is that the controller does not use any form of RAM
to decode IP fragments into UDP packets.  This means that the controller
does not handle out-of-order fragments and other cases that a complete
TCP/IP stack can.  This is discussed in more detail later.

Secondly, the SPI bus is the limiting factor in how fast audio data can
be received (the audio bitrate for playback).  In order to gain the
maximum efficiency from the SPI bus, the ethernet controller will
simulataneously queue an SPI read command to read audio data from the
ENC424J600's buffer, and queue an SDRAM write command for the previously
read audio data.  The SPI cycle and SDRAM cycle are asynchronous with
respect to each other, so there is quite a bit of extra logic and
circuitry required for this to work.


## High-level states

All of the states are defined in the ETHERNET_STATES enumeration.


### Initialization

States starting with INIT_ handle the initialization of the ENC424J600
device.  This is outlined in the device's documentation and will not
be repeated here.  One step that is performed here is to read the
device's MAC address so that it can be used later when transmitting
packets.

Once the device has been initialized, the state machine enters the
IDLE state.


### Interrupt handling

Interrupt handling is done by the INT_ states.  The two interrupts
that are enabled are the Link Status interrupt and the Packet
Received interrupt.

The Link Status interrupt is handled in the LINK_ states.  If the
new link status is "connected" (or "enabled") then the device's
registers are programmed based on the documentation and packet
receiption is enabled.  The ethernet controller state machine
then begins DHCP broadcasts.  If no DHCP server is found, an IP
address in the link-local range is selected (169.254/16).

It should be noted that the implementation of DHCP and link-local
address selection does not completely follow the RFCs.  Just enough
of each protocol is implemented such that it works in practice
(from my testing).  As one example, the link-local address that
is selected is not random, nor does the FPGA send address probes
to detect conflicts with other hosts.  Since the device is intended
to work on a very small LAN with more-or-less one PC and the
Logi-pi, the chance of a conflict is minimal.

DHCP is handled in the DHCP_DISCOVER_, DHCP_REQUEST_, and
RX_DHCP_ states.


### Status Updates

While in the IDLE state, and if an IP address has been chosen,
then a timer runs to count to approximately once every 1/10 of a
second and once every second.  If there is no data in the SDRAM
buffer, then during the 1Hz counter the ethernet controller will
send a UDP broadcast with status updates.  This is handled in
the TX_STATUS_ states.  If there is data in the SDRAM buffer
(presumably because some audio is playing), then the 10Hz counter
is used instead but the same states are triggered.


### Ethernet Decoding

When an packet received interrupt is triggered, the state machine
will enter the RX_ set of states.  These branch out into RX_ARP_
for ARP packets, RX_IP_ for IP packets, and RX_UDP_/RX_AUDIO_
for IP fragments that form a UDP datagram containing the audio
data.

Decoding the Ethernet packets requires very little logic because
it is mostly handled by the ENC424J600.  The ENC424J600 is
programmed to only accept unicast packets to its MAC address
and broadcasts, both of which are important here.  The device also
checks CRC and other error conditions and discards those packets
so the state machine does not need to do this.


### ARP

The ethernet controller listen for ARP requests.  When a request
is received for its IP address, it responds with an ARP reply.
The controller does not perform requests because it only ever
sends IP broadcasts, so it does not need to perform address
lookups.


### IP

IP packet (fragment) handling is one of the more complex processes.
As mentioned previously, IP packets are not buffered in the FPGA
or SDRAM.  Registers are used when needed to store some of the
header information for a later state.  This means that the state
machine both reads data from the ENC424J600's buffer and processes
the data in the next state (as the next read command is being set
up).  An example of this is computing the IP header checksum while
reading the IP header and saving some parts of the header into
registers for later.

UDP datagrams are divided into IP fragments (up to 1480 bytes).
A full TCP/IP implementation would handle various cases, like
IP fragments that are received out of order or that have
overlapping data in them (the latter is probably rare).  To do
this requires holding the IP fragments in a buffer until the
entire UDP datagram has been assembled, and then passing the
datagram to a higher-level protocol handler.

Instead of following the standard implentation, the state machine
both reads and decodes data in the same set of states.  This means
that the state machine acts as though the IP fragments will be
received in the perfect case; in order, no overlaps, and none are
missing.  It records the next expected fragment offset while
reading processing fragments and when the next fragment is received
it checks the next expected value against the received fragment.
If they do not match then the fragment is discarded.  A fragment
offset of zero is always recognized to begin a new UDP datagram.

There is also some additional complexity because an even audio
sample may span two IP fragments.  At the end of previous fragment
the partial sample is saved in a register and at the start of the
next fragment is concatenated with a short read of the first data
in the fragment to complete the sample.

As audio data is being buffered in the SDRAM under this
"optimistic" IP fragment assembly, the write pointer to the SDRAM
is not shared outside of the ethernet controller.  The
write_complete pointer is what the DAC controller actually sees
for the last written location.  This way, the ethernet controller
can "abort" the buffering of audio data by backing up the write
pointer in the case that some IP fragments are lost and the
datagram needs to be retransmitted.

For a discussion of further issues relating to the reassembly of
IP fragments, see the document on the network protocol.


### UDP

Most of the work involved in handling UDP datagrams is in the
reassembly of the IP fragments, as discussed above.  The first IP
fragment has the UDP header, so the port number can be checked,
but otherwise the UDP layer is practically invisible.

The ethernet controller does not check the UDP checksum while
reading data.  It also does not generate UDP checksums when
transmitting status updates or DHCP requests.



