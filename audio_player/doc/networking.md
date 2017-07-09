# Network Protocol

## Architecture

The network protocol is controlled by a large state machine in ethernet.vhd.

When the state machine has finished initalizing, it will first perform a
DHCP broadcast to automatically obtain an IP address.  If no DHCP servers
respond, then the state machine will choose an automatic link-local IP
address in the 169.254.0.0/16 range.  This implementation does not completely
follow the RFCs for DHCP and link-local IP selection, but does implement
just enough of these protocols to work sufficiently.

(To speed up the initialization when the device is not plugged into an
Internet router, DHCP can be bypassed by setting SW1 to ON.)

Once the device has an IP address, it will begin broadcasting UDP packets
to 255.255.255.255 on UDP port 9001 once every second.  When audio data
is being transfered to the device, the broadcast interval will increase
to 1/10th of a second, but will back down to once every second after
the device is idle again.

The host PC can then listen for these broadcasts to determine the IP address
of the device automatically, and also to monitor the state of the device
while sending audio to it.

The host PC sends audio data to the device by sending UDP datagrams to
the device's IP address and port 9000.  The format of the packets is
detailed below.


## Packet Structure

### Status updates (device to PC)

* UDP datagrams to port 9001

| Field | Size | Purpose |
| ----- | ---- | ------- |
| Next expected sequence number | 32-bit, big endian | For every byte of audio data transmitted, both the device and PC will increment this sequence number. |
| ----- | ---- | ------- |
| Buffer (window) size | 32-bit, big endian | The buffer size remaining for storing audio data. A value close to zero indicates that the buffer is full and the host should send data more slowly. |
| ----- | ---- | ------- |
| Status bits | 32-bit, big endian | Bit 0 is set if no 16.9 MHz clock is detected |
| ----- | ---- | ------- |


### Audio data and commands (PC to device)

* UDP datagrams to port 9000

| Field | Size | Purpose |
| ----- | ---- | ------- |
| Command | 32-bit, big endian | Command flags.  See below. |
| ----- | ---- | ------- |
| Sequence number | 32-bit, big endian | For every byte of audio data transmitted, both the device and PC will increment this sequence number. |
| ----- | ---- | ------- |
| Audio data | An even multiple of 6, 20-bit samples (stored in 3 bytes each), each is big endian. | The audio data for the device to play. |
| ----- | ---- | ------- |

Command bits:

* Bit 31 (MSB): If this is set then no audio data will be contained in the
  packet.  In other words, the packet is a command and sequence number only.

* Bit 17: Set the user signal to logic one (on).  This can be used to turn
  on a relay that controls the power input for the amplifiers.

* Bit 16: Set the user signal to logic zero (off).

* Bit 8: Force a reset of the D-to-A state machine.

* Bit 2: Pause the D-to-A state machine.  All of the audio data currently
  buffered will remain as-is and the state machine will continue running
  but will output samples of zeros to all channels.  The PC can stop
  sending data, and the next data packet should have this bit unset to
  resume playback.

* Bit 1: Set sequence number. Instead of checking the sequence number
  against the next expected value, the sequence number will be overwritten
  with the value provided by the host PC.  This is used for the first audio
  data packet to align the device's sequence number to the PC's (typically
  zero).

* Bit 0: Mute audio output.  Data will still be transferred through the
  D-to-A state machine and so the host PC will need to continue supplying
  data.  However the output data signals are ANDed with the inverse of this
  bit so that a value 1 will cause all of the samples to be zeros.


## Normal Data flow

### Sending audio data

The host PC will listen for UDP broadcasts on port 9001.  Once received, the
PC can then begin sending audio data to the device.

The first data packet will have the command set to 0x00000102 to reset the
D-to-A state machine (flushing any audio currently being played from the
buffer) and sychronizing the sequence number on the device.  The sequence
number can be set to anything, but zero is a good choice.  The audio data
will contain 20-bit samples where the lower 4 bits of each 3-byte sample are
ignored.  There will be an even multiple of 8 samples, one per channel.

The number of audio samples to send in each UDP data packet is chosen by
the host PC.  However, the ethernet state machine programs the ENC424J600
to allow for 22KB of ethernet data to be buffered in the chip (including
ethernet and IP headers for each IP fragment).  For the best efficency,
the host should send as much data as can fit in this space.  The C#
implentation here uses 20,088 bytes (a multiple of 8 24-bit words).

The normal data rate that the host PC should send at can then be computed
as: 1,058,400 bytes per second divided by 20,088 bytes per packet. While
sending data, the PC will listen for UDP broadcasts on port 9001.  Using
the buffer size field (window) the PC can determine if the device needs
more data to maintain a nearly-full buffer, or if the buffer is close to
full and so the PC can slow down.  At first the PC should send data at
2 or 3 times the normal data rate, and it can back down to half the data
rate if needed.

Another complication is that the SPI protocol between the FPGA and the
ENC424J600 is limited to slightly less than 12 mbit/sec, or 1.5 mbyte/sec
(constraned by the SPI clock of 12MHz).  If the PC sends data any faster
than that, the ENC424J600's internal buffer will overflow and packets
will be discarded, which will result in re-transmission (see below for
details) and further bandwidth wasted.

See EthernetAudio.getEstimatedSleepLength() in C# for the heuristics
used, including the 15 millisecond minimum sleep time (1,500,000 /
20,088 = ~74.6Hz or 13ms, which we round up a bit).


### Receiving audio data

When a datagram is recieved from the PC, the device will process it and
compare the sequence number of the packet recieved to the next expected
sequence number.  If these do not align, then the packet is discarded.
If they do match, then the audio data is added to the SDRAM buffer.


## Error detection and handling

### Missing IP fragments

If one or more fragments of a UDP datagram are lost, the entire datagram
is discarded. (See the document about the Ethernet state machine for why
this is the case).  It appears that during normal operation this happens
once every few minutes.

When the device discards the packet the next expected sequence number
will not be incremented.  Further audio data packets will then also be
discarded as the PC continues to increment the sequence number but the
device does not.

Eventually the PC will recieve a status packet and will determine that
the device's sequence number is too far behind.  (For example, a good
estimate would be half a second or so since that would correspond to
roughly 5 status updates showing no progress being made.)  Based on this
guess, the PC will retry the data packets that were sent previously,
starting with the next expected sequence number.

The device will then receive the resent datagram with all IP fragments
necessary that match the next expected sequence number.  During this
time the SDRAM buffer will be less full because no data was being
written to it.  If the available buffer size becomes too large then
the PC will speed up transmission to refill the buffer.  Data transfer
can then then resume normally.

It is possible that resent datagrams will also have missing IP
fragments.  The SDRAM buffer size needs to be large enough such that
the probability of running out of audio data because of multiple
lost data packets is very low.  The Logi-PI has a large SDRAM chip
that can buffer several seconds of audio data.  However, a bad Ethernet
cable could cause enough packet loss that the device runs out of audio
to play.

The amount of SDRAM to use as buffer space can be tuned to find a balance
between the delay when starting playback versus the probability of data
underruns.


### Duplicate audio data

Because the PC decides to retransmit datagrams based on the status
packets (a guess really), it is possible that the PC may decide to
retransmit datagrams when they are not needed, resulting in duplicate
data.

To the device, this is no different than missing IP fragments or missing
entire datagrams.  The sequence number of the duplicated data will not
match the next expected sequence number and so they will be discarded.
This will result it time wasted, but eventually the sequence number
from the PC will be incremented back to the next expected value of
the device and processing will continue normally.  However, even if that
does not happen (such as if the host PC sends datagrams of varying sizes
and skips over the next expected sequence), then the host PC will realize
that the device is not accepting data and can go back to exactly the
right sequence number like in the case of lost packets.

Again, the goal is to have enough data in the SDRAM buffer such that
these hiccups will not cause the buffer to empty completely.


### Corrupted data

There is currently no mechanism in place to detect data corruption
due to Ethernet errors.  UDP datagrams have a 16-bit checksum that can
be used but the device does not check this and the device does not
generate a checksum when transmitting status packets.  This could be
improved in the future.
