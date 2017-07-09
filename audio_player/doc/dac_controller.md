# DAC Controller

## Architecture

The DAC controller contains two state machines that operate in two
independent clock domains.  The first is the state machine that reads
data from the SDRAM and stores it in the SRAM.  The second is the
state machine that reads data from the SRAM and drives the 8 D-to-As.

Because there are two different clock domains (100MHz and 16.9MHz),
there are also many signals that need to be synchronized between them.
Currently some signals do not pass the Xilinx timing analysis, but
the state machines work in practice.

The SDRAM->SRAM state machine controls whether the SRAM->D-to-A
state machine is permitted to run.  The SDRAM->SRAM state machine
may hold the other in a partial "reset" at certain points, so that
no data is read from the SRAM when it is empty.


## Reading SDRAM

This state machine operates in the 100MHz clock domain, along with
the Ethernet controller and SDRAM controller.  This allows it to
read data as fast as possible from the SDRAM to keep the SRAM buffer
full.

The states for this state machine are in the BUFFER_STATES
enumeration.

The state machine is divided into two sets of states, but both
perform the same basic function.  The main function is to read a
sample (32-bit word) from the SDRAM, wait for completion, and then
save it in the SRAM also as a 32-bit word.  The samples are not
changed in any way, except for the highest bit of the 32-bit word,
which is used for signalling and not part of the sample itself.

The difference between the INIT_ states and the remaining states
is in when more data is read from the SDRAM.  In the INIT_
states, the entire SRAM is filled as quickly as possible.  After
that, the state machine waits until the sdram_buffer_below_minimum
signal is de-asserted, thereby indicating that there is also 
sufficient data in the SDRAM buffer for the future.  This way
issues like random Ethernet packet loss will not cause the audio
playback to stutter while the SDRAM buffer is filling up.

The states that don't begin with INIT_ are the normal set of states
which shuffle data from the SDRAM to the SRAM as the SRAM empties.
At the end of the INIT_ states, the SRAM->DAC state machine is
taken out of reset state so that playback will begin.  The
SDRAM->SRAM state machine spends most of its time in the IDLE state
until one of two things happen:


1. The SDRAM buffer becomes empty.  The state machine goes back to
the INIT state to wait until the buffers are full enough to resume
playback.  (This causes a longer silence than a stutter, but reduces
the chance of continual stuttering if the buffer never quite fills
up enough.)  We don't expect this to happen normally, except if the
PC stops sending data or the Ethernet is disconnected.

2. The highest bit of the SRAM read pointer (updated by the other
state machine) changes.  This means that half of the SRAM is now
empty.  This state machine will read 32-bit samples from the SDRAM
and write to the now-empty half of the SRAM, and returns to the IDLE
state once it reaches the next half (which should still be in use
by the reader).

While data is being transferred from the SDRAM to the SRAM, the
top-most bit of the 32-bit word is tagged at the beginning of every
8 sample frame. The PC will signal that a data packet is the
beginning of an audio stream by forcing the sequence counter to
zero, and when that happens, the Ethernet state machine will tag
top-most the word containing first sample when writing it to SDRAM.
This state machine then synchronizes to that and counts every 8
samples, tagging every 8th one.  The SRAM->DAC state machine will
then use that top-most bit to ensure that the first sample always
goes to the left woofer D-to-A, so that the signals are not sent
to the wrong speakers.  (Sending loud low frequency signals to
a tweeter may ruin it!)


## Reading SRAM and generating D-to-A signals

The state machine that reads from the SRAM also generates all of
the D-to-A signals, including Bit Clock, Latch Enable, and 8 serial
data signals.

When this state machine is held in partial "reset" by the other
state machine, it generates the Bit Clock and Latch Enable signals,
but instead of transferring data from SRAM, it sends zeros in the
serial data signals.  This will output silence (0 volts) to the
speakers.  The state machine starts in a partial reset state and
will be placed in this state if the SRAM buffer is emptied or
the PC host sends a command to stop playback (DAC RESET).

Otherwise, most of the complexity here is in generating the read
signals to the SRAM at the right times, capturing the data in
shift registers, and shifting the data out to the D-to-As.  All
of this happens in phase with the generated Latch Enable which is
why this state machine generates all of these signals at once.

This is also the point where the 24-bit audio data from the PC
host, which was stored in 32-bit words in SDRAM and SRAM, is now
truncated to 20 bits.  The 8 bits in SDRAM and lower 4 bits of
the 24-bit sample are discareded.

It should be noted that the basic structure of this state machine
was borrowed from my friend's previous VHDL implementation with
the USB device.
