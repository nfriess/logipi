using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Diagnostics;

namespace AudioPlayer
{
    struct PacketData
    {
        public UInt32 seq;
        public byte[] data;
    }

    /// <summary>
    /// Connects to an amplifier over the network and allows sending
    /// of audio data using the Walpole protocol.
    /// 
    /// Basic usage...
    /// 
    /// eth = new EthernetAudio();
    /// 
    /// To provide a nice UI showing when the amplifier is connected:
    /// 
    /// eth.AmplifierConnected += ...
    /// eth.AmplifierDisconnected += ...
    /// 
    /// Check that the amplifier is connected before sending any data:
    /// 
    /// if (eth.isAmplifierConnected()) ...
    /// 
    /// Send data:
    /// 
    /// eth.sendAudioData(data, true);
    /// 
    /// while (...)
    /// {
    ///     eth.sendAudioData(data, false);
    ///     
    ///     Thread.Sleep(eth.getEstimatedSleepLength(data.Length));
    /// }
    /// 
    /// Clean up when done:
    /// 
    /// eth.sendStop();
    /// eth.Dispose();
    /// 
    /// There is also sendMuteOn and sendMuteOff to mute and pause playback.
    /// 
    /// </summary>
    class EthernetAudio : IDisposable
    {

        public const UInt32 CMD_MUTE = 0x00000001;
        public const UInt32 CMD_SET_SEQUENCE = 0x00000002;
        public const UInt32 CMD_PAUSE = 0x00000004;
        public const UInt32 CMD_RESET_I2S = 0x00000100;
        public const UInt32 CMD_USER_SIG_OFF = 0x00010000;
        public const UInt32 CMD_USER_SIG_ON = 0x00020000;

        public const UInt32 STATUS_CLOCK_WARNING = 0x00000001;


        /// <summary>
        /// Socket to send data to amplifier
        /// </summary>
        private UdpClient udpSend;

        /// <summary>
        /// Socket to receive status updates from amplifier
        /// </summary>
        private UdpClient udpStatus;

        /// <summary>
        /// Amplifier's IP address (filled in once first status is received)
        /// </summary>
        private IPAddress ampIPAddress;

        /// <summary>
        /// Window size recevied from most recent status update
        /// </summary>
        private volatile UInt32 recvWindowSize;

        /// <summary>
        /// Sequence number received from last status update
        /// </summary>
        private volatile UInt32 recvSequenceLast;

        /// <summary>
        /// Sequence number received from most recent status update
        /// </summary>
        private volatile UInt32 recvSequence;

        /// <summary>
        /// Sequence number sent in last data packet
        /// </summary>
        private volatile uint sendSequence;

        /// <summary>
        /// All of the packets that have not been acknowledge (seq less than recvSeq)
        /// are in this queue.
        /// </summary>
        private Queue<PacketData> packetInProgress;

        /// <summary>
        /// The last time the amplifier sent a status update
        /// </summary>
        private DateTime lastSeenTime;

        /// <summary>
        /// A timer to fire off our disconnected event if we don't receive updates from the amplifier
        /// </summary>
        private Timer expectedStatusTimer;

        /// <summary>
        /// Additional status information sent from device
        /// </summary>
        private volatile UInt32 statusBitmask;

        private bool didConnectSender;
        private bool isMute;
        private bool isPaused;

        public delegate void AmplifierConnectedHandler(object sender);
        /// <summary>
        /// Fired when the amplifier is found on the network.
        /// </summary>
        public event AmplifierConnectedHandler AmplifierConnected;

        /// <summary>
        /// Fired when the amplifier is lost (after a timeout).
        /// </summary>
        public event AmplifierConnectedHandler AmplifierDisconnected;

        public delegate void StatusReceivedHandler(object sender, UInt32 sequence, UInt32 windowSize);
        
        /// <summary>
        /// Fired for every status update recieved from the amplifier.
        /// </summary>
        public event StatusReceivedHandler StatusReceived;

        public EthernetAudio()
        {
            ampIPAddress = null;
            didConnectSender = false;
            isMute = true;
            isPaused = true;

            sendSequence = 0;
            packetInProgress = new Queue<PacketData>();

            udpSend = new UdpClient(AddressFamily.InterNetwork);

            Init();
        }

        public void Init()
        {
            if (udpStatus != null)
                Dispose();

            lastSeenTime = DateTime.Now;
            expectedStatusTimer = new Timer(onStatusTimeout, null, 1000, 1000);

            udpStatus = new UdpClient(9001);

            udpStatus.BeginReceive(new AsyncCallback(onStatusReceived), null);
        }

        public void Dispose()
        {
            if (udpStatus != null)
            {
                udpStatus.Client.Shutdown(SocketShutdown.Both);
                udpStatus = null;
            }
        }

        public bool isAmplifierConnected()
        {
            return didConnectSender;
        }

        public IPAddress getAmplifierIPAddress()
        {
            return ampIPAddress;
        }

        public UInt32 getSendSequence()
        {
            return sendSequence;
        }

        public UInt32 getRecvSequence()
        {
            return recvSequence;
        }

        public UInt32 getWindowSize()
        {
            return recvWindowSize;
        }

        public int getQueueLen()
        {
            return packetInProgress.Count;
        }

        public UInt32 getStatusBitmask()
        {
            return statusBitmask;
        }

        /// <summary>
        /// Returns the number of milliseconds that we need to sleep
        /// between packets, based on the given packet length and
        /// the amount of data available in the amplifier's buffer
        /// </summary>
        /// <param name="packetSize"></param>
        /// <returns></returns>
        public int getEstimatedSleepLength(int packetSize)
        {
            // At 24 bits per sample, 8 channels...
            //
            // 1,058,400 bytes will be needed per second
            //

            // We need to send this many packets per second
            double pktsPerSec = (double)1058400 / (double)packetSize;

            // For a total of 1000 ms we need to sleep this long
            int msPerSleep = (int)Math.Floor(1000.0 / pktsPerSec);

            if (recvWindowSize > packetSize*10)
                msPerSleep = msPerSleep / 3; // Buffer is low, need to fill faster
            else if (recvWindowSize < packetSize*4)
                msPerSleep = msPerSleep * 2; // Buffer is nearly full, need to fill slower

            // Set a hard minimum
            if (msPerSleep < 15)
                msPerSleep = 15;

            return msPerSleep;
        }

        public int sendAudioData(byte[] data, int dataLen, bool newAudioStream)
        {
            if (dataLen > data.Length)
                throw new Exception("dataLen is greater than data.Length");

            if (dataLen % 6 != 0)
                throw new Exception("Data must contain 2 channels of 24 bit samples, a multiple of 6 bytes per packet.");

            if (dataLen > 21000)
                throw new Exception("Amplifier can only accept up to 21,000 bytes per packet.");

            if (!didConnectSender)
            {
                // Wait a little bit to see if it will come back...
                Thread.Sleep(2000);

                if (!didConnectSender)
                    throw new Exception("Have not received any status updates yet.");
            }

            if ((statusBitmask & STATUS_CLOCK_WARNING) == STATUS_CLOCK_WARNING)
                throw new Exception("The audio clock does not appear to be running.");

            int START_RETRIES = 7;
            int retries = START_RETRIES;

            int packetInProgressCount;

            lock (packetInProgress)
            {
                packetInProgressCount = packetInProgress.Count;
            }

            while (retries > 0 && packetInProgressCount > 20)
            {
                Debug.WriteLine(String.Format("{0:HH:mm:ss:fff}: Retry {4}.  Expected: {1:#,##0} but have {2:#,##0}, diff={3:#,##0}",
                    DateTime.Now, sendSequence, recvSequence, (sendSequence - recvSequence), (START_RETRIES - retries + 1)));

                resendMissingPackets();

                retries--;

                // Wait for next status to come in
                //Thread.Sleep(500);

                lock (packetInProgress)
                {
                    packetInProgressCount = packetInProgress.Count;
                }

            }

            if (retries == 0)
            {
                throw new Exception("Retried packets too many times.  Queue lenth = " + packetInProgressCount);
            }



            // Command will below will unpause automatically
            isPaused = false;

            byte[] pktBytes = new byte[dataLen + 8];

            // Command
            pktBytes[0] = 0;
            pktBytes[1] = 0;
            pktBytes[2] = 0;
            pktBytes[3] = 0;

            // Always reset mute when starting a new stream
            if (newAudioStream)
                isMute = false;

            if (isMute)
                pktBytes[3] |= 0x01;

            if (newAudioStream)
            {
                sendSequence = 0;

                // Reset sequence to 0 and stop anything that is playing
                sendCommand(CMD_RESET_I2S | CMD_SET_SEQUENCE | CMD_MUTE, sendSequence);
                
                // Forget any pending audio data
                lock (packetInProgress)
                {
                    packetInProgress.Clear();
                }

                // Let any status messages be processed first
                Thread.Sleep(1000);

            }

            byte[] seqData = BitConverter.GetBytes(sendSequence);

            // Sequence
            pktBytes[4] = seqData[3];
            pktBytes[5] = seqData[2];
            pktBytes[6] = seqData[1];
            pktBytes[7] = seqData[0];

            Array.Copy(data, 0, pktBytes, 8, dataLen);

            PacketData pkt = new PacketData();
            pkt.seq = sendSequence;
            pkt.data = pktBytes;

            lock (packetInProgress)
            {
                packetInProgress.Enqueue(pkt);
            }

            int retVal = udpSend.Send(pktBytes, pktBytes.Length);

            if (retVal == pktBytes.Length)
                sendSequence += (uint)dataLen;

            return retVal;
        }

        public void sendMuteOn()
        {
            uint bitmask = CMD_MUTE;
            if (isPaused)
                bitmask |= CMD_PAUSE;

            sendCommand(bitmask, 0);

            isMute = true;
        }

        public void sendMuteOff()
        {
            uint bitmask = 0; // No mute bit
            if (isPaused)
                bitmask |= CMD_PAUSE;

            sendCommand(bitmask, 0);

            isMute = false;
        }

        public void sendStop()
        {
            sendCommand(CMD_RESET_I2S | CMD_MUTE, 0);

            // Forget any pending audio data
            lock (packetInProgress)
            {
                packetInProgress.Clear();
            }
        }

        public void sendPauseOn()
        {
            uint bitmask = CMD_PAUSE;
            if (isMute)
                bitmask |= CMD_MUTE;

            sendCommand(bitmask, 0);

            isPaused = true;
        }

        public void sendPauseOff()
        {
            uint bitmask = 0; // No pause bit
            if (isMute)
                bitmask |= CMD_MUTE;

            sendCommand(bitmask, 0);

            isPaused = true;
        }

        public void sendUserSignal(bool value)
        {
            uint bitmask;

            if (value)
                bitmask = CMD_USER_SIG_ON;
            else
                bitmask = CMD_USER_SIG_OFF;

            if (isMute)
                bitmask |= CMD_MUTE;

            if (isPaused)
                bitmask |= CMD_PAUSE;

            sendCommand(bitmask, 0);
        }

        private void sendCommand(UInt32 command, UInt32 sequence)
        {
            byte[] pktData = new byte[8];

            byte[] data = BitConverter.GetBytes(command);

            // 0x80 means that no audio data will follow
            pktData[0] = (byte)(0x80 | data[3]);
            pktData[1] = data[2];
            pktData[2] = data[1];
            pktData[3] = data[0];

            data = BitConverter.GetBytes(sequence);

            pktData[4] = data[3];
            pktData[5] = data[2];
            pktData[6] = data[1];
            pktData[7] = data[0];

            udpSend.Send(pktData, pktData.Length);
        }

        /// <summary>
        /// Call this method to ensure that any missing packets
        /// are retransmitted to the amplifier.
        /// </summary>
        public void resendMissingPackets()
        {

            PacketData[] packets;

            lock (packetInProgress)
            {

                if (packetInProgress.Count < 1)
                    return;


                packets = packetInProgress.ToArray();

            }

            int pktNum = 0;
            PacketData pkt;

            // We might have kept some extra full packets around...
            while (pktNum < packets.Length)
            {
                pkt = packets[pktNum];

                // Same check as dequeue except without the *3
                if (pkt.seq < recvSequence && (recvSequence - pkt.seq) >= (pkt.data.Length - 8))
                {
                    pktNum++;
                }
                else
                {
                    break;
                }
            }

            if (pktNum == packets.Length)
                return;

            while (pktNum < packets.Length)
            {
                pkt = packets[pktNum];

                // Reset sequence counter
                sendSequence = pkt.seq;

                //Debug.WriteLine(String.Format("Resend {0:#,##0} of len {1:#,##0}", sendSequence, pkt.data.Length - 8));

                // Send packet
                udpSend.Send(pkt.data, pkt.data.Length);

                // New sequence counter
                sendSequence = pkt.seq + ((uint)pkt.data.Length - 8);

                // Wait for amplifier to process the data
                Thread.Sleep(getEstimatedSleepLength(pkt.data.Length - 8));

                pktNum++;
            }

        }

        private void onStatusReceived(IAsyncResult res)
        {
            if (!res.IsCompleted)
                return;

            if (udpStatus == null)
                return;

            IPEndPoint rmtEndpoint = new IPEndPoint(IPAddress.Any, 9001);

            byte[] data = udpStatus.EndReceive(res, ref rmtEndpoint);

            ampIPAddress = rmtEndpoint.Address;

            lastSeenTime = DateTime.Now;

            byte[] seqData = new byte[4];
            // Convert big endian to little endian
            seqData[0] = data[3];
            seqData[1] = data[2];
            seqData[2] = data[1];
            seqData[3] = data[0];

            recvSequenceLast = recvSequence;
            recvSequence = BitConverter.ToUInt32(seqData, 0);

            byte[] windowData = new byte[4];
            // Convert big endian to little endian
            windowData[0] = data[7];
            windowData[1] = data[6];
            windowData[2] = data[5];
            windowData[3] = data[4];

            recvWindowSize = BitConverter.ToUInt32(windowData, 0);

            byte[] statusData = new byte[4];
            // Convert big endian to little endian
            statusData[0] = data[11];
            statusData[1] = data[10];
            statusData[2] = data[9];
            statusData[3] = data[8];

            statusBitmask = BitConverter.ToUInt32(statusData, 0);

            if (!didConnectSender)
            {
                IPEndPoint epSend = new IPEndPoint(ampIPAddress, 9000);

                udpSend.Connect(epSend);

                didConnectSender = true;

                try
                {
                    if (AmplifierConnected != null)
                        AmplifierConnected(this);
                }
                catch (Exception ex) { }
            }

            // This fails if a status update comes in too quickly...
            // the first set of packets will be dequeued before the real
            // ACK comes in.  A work-around is in the send method above
            // where it waits for a litle bit after sending a reset command.

            lock (packetInProgress)
            {
                while (packetInProgress.Count > 0)
                {

                    ulong recvSeqLong = recvSequence;

                    PacketData pkt = packetInProgress.Peek();

                    // Handles the case where the amp's sequence has wrapped around
                    if (pkt.seq > 0xFFF00000 && recvSeqLong < 0x00080000)
                    {
                        recvSeqLong += 0x100000000;
                    }

                    if (pkt.seq < recvSeqLong && (recvSeqLong - pkt.seq) >= 3 * ((ulong)pkt.data.Length - 8))
                    {
                        packetInProgress.Dequeue();
                    }
                    else
                    {
                        break;
                    }
                }

            }

            try
            {
                udpStatus.BeginReceive(new AsyncCallback(onStatusReceived), null);
            }
            catch (Exception ex) { }

            try
            {
                if (StatusReceived != null)
                    StatusReceived(this, recvSequence, recvWindowSize);
            }
            catch (Exception ex) { }

        }

        private void onStatusTimeout(Object state)
        {
            TimeSpan elapsedTime = (DateTime.Now - lastSeenTime);

            if (didConnectSender && elapsedTime.Seconds > 8)
            {
                didConnectSender = false;

                try
                {
                    if (AmplifierDisconnected != null)
                        AmplifierDisconnected(this);
                }
                catch (Exception ex) { }

            }

        }

    }
}
