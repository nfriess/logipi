using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.IO;
using System.Diagnostics;

namespace AudioPlayer
{
    public partial class Form1 : Form
    {
        private Thread audioThread = null;
        private volatile bool stopAudio;
        private volatile bool needPause;

        private volatile String waveFileName;

        private EthernetAudio ethAudio;

        private delegate void UpdateDisplayCallback(UInt32 sequence, UInt32 windowSize);

        public Form1()
        {
            InitializeComponent();

            ethAudio = new EthernetAudio();

            ethAudio.StatusReceived += new EthernetAudio.StatusReceivedHandler(onStatusReceived);

            ethAudio.AmplifierConnected += new EthernetAudio.AmplifierConnectedHandler(onAmplifierConnected);
            ethAudio.AmplifierDisconnected += new EthernetAudio.AmplifierConnectedHandler(onAmplifierDisconnected);

        }

        private void onStatusReceived(object sender, UInt32 sequence, UInt32 windowSize)
        {
            UpdateDisplayCallback cb = new UpdateDisplayCallback(updateDisplay);
            this.Invoke(cb, new object[] {
                sequence, windowSize
            });
        }

        private void onAmplifierConnected(object sender)
        {
            UpdateDisplayCallback cb = new UpdateDisplayCallback(updateDisplay);
            this.Invoke(cb, new object[] {
                (UInt32)0, (UInt32)0
            });
        }

        private void onAmplifierDisconnected(object sender)
        {
            UpdateDisplayCallback cb = new UpdateDisplayCallback(updateDisplay);
            this.Invoke(cb, new object[] {
                (UInt32)0, (UInt32)0
            });
        }

        private void updateDisplay(UInt32 sequence, UInt32 windowSize)
        {
            if (ethAudio.isAmplifierConnected())
                lblIP.BackColor = Color.LightGreen;
            else
                lblIP.BackColor = Color.Red;

            if (ethAudio.getAmplifierIPAddress() != null)
                lblIP.Text = ethAudio.getAmplifierIPAddress().ToString();

            lblWindow.Text = "Window: " + String.Format("Window Size: {0:X}", windowSize);

            lblSeqDiff.Text = "Outstanding: " + (ethAudio.getSendSequence() - ethAudio.getRecvSequence());
            lblQueueLen.Text = "Queue Len: " + ethAudio.getQueueLen();

        }

        private void sendTestDataFunc()
        {
            uint count = 1;

            // About 1/13 of a second
            byte[] pktData = new byte[20100];

            bool firstPacket = true;

            using (new TimePeriod(1))
            {

                while (!stopAudio)
                {
                    if (needPause)
                    {
                        ethAudio.sendPauseOn();

                        while (needPause)
                        {
                            Thread.Sleep(100);
                        }

                        ethAudio.sendPauseOff();
                    }


                    for (int i = 0; i < pktData.Length; i += 6)
                    {
                        
                        pktData[i] = (byte)((count >> 16) & 0xFF);
                        pktData[i + 1] = (byte)((count >> 8) & 0xFF);
                        pktData[i + 2] = (byte)(count & 0xFF);

                        pktData[i + 3] = (byte)(((count >> 16) & 0xFF) ^ 0xFF);
                        pktData[i + 4] = (byte)(((count >> 8) & 0xFF) ^ 0xFF);
                        pktData[i + 5] = (byte)((count & 0xFF) ^ 0xFF);
                    }

                    // About 1 second of audio data
                    for (int pktnum = 0; pktnum < 13; pktnum++)
                    {

                        ethAudio.sendAudioData(pktData, pktData.Length, firstPacket);

                        firstPacket = false;

                        Thread.Sleep(ethAudio.getEstimatedSleepLength(pktData.Length));
                    }

                    count = count * 2;
                    if (count == 0x100000)
                        count = 1;
                }

            }

            //ethAudio.sendStop();

        }

        private void sendCounterFunc()
        {
            //uint count = (uint)(new Random().Next()) % (1<<20);
            uint count = (uint)(new Random().Next() | 0x10000) % (0x100000);

            byte[] pktData = new byte[20100];

            bool firstPacket = true;

            using (new TimePeriod(1))
            {

                while (!stopAudio)
                {
                    if (needPause)
                    {
                        ethAudio.sendPauseOn();

                        while (needPause)
                        {
                            Thread.Sleep(100);
                        }

                        ethAudio.sendPauseOff();
                    }


                    for (int i = 0; i < pktData.Length; i += 3)
                    {
                        pktData[i] = (byte)((count >> 16) & 0xFF);
                        pktData[i + 1] = (byte)((count >> 8) & 0xFF);
                        pktData[i + 2] = (byte)(count & 0xFF);

                        count++;

                        if (count > 0x100000)
                            count = 0x10000;

                    }

                    ethAudio.sendAudioData(pktData, pktData.Length, firstPacket);

                    firstPacket = false;

                    Thread.Sleep(ethAudio.getEstimatedSleepLength(pktData.Length));
                }

            }

            ethAudio.sendStop();

        }

        private void sendWaveFunc()
        {
            FileStream wavFile = new FileStream(waveFileName, FileMode.Open, FileAccess.Read, FileShare.Read);

            int bytesRead;

            // 1 second = 176,400 bytes at 16 bits (WAV file)
            // 1 second = 793,800 bytes at 24 bits (packet data)

            // Max buffer is 22K in ethernet chip

            // Read chunks out of WAV file such that 18/4 of the size
            // is a nice round number
            byte[] wavData = new byte[4468];

            // 20,100 bytes is about 1/40 of a second
            byte[] ethData = new byte[20106];

            bool firstPacket = true;

            using (new TimePeriod(1))
            {

                while (!stopAudio)
                {
                    if (needPause)
                    {
                        ethAudio.sendPauseOn();

                        while (needPause)
                        {
                            Thread.Sleep(100);
                        }

                        ethAudio.sendPauseOff();
                    }

                    // Only check sequence 1/4 of the time
                    for (int pktnum = 0; pktnum < 4; pktnum++)
                    {

                        bytesRead = wavFile.Read(wavData, 0, wavData.Length);

                        int pktDataI = 0;

                        // Swap little endian for big endian, expand into 20 bits, and multiply by 3 channels
                        // (top 4 bits and bottom 4 bits are zeros)
                        for (int i = 0; i < bytesRead; i += 4)
                        {
                            uint leftSample = ((uint)wavData[i + 1] << 12) | ((uint)wavData[i] << 4);
                            uint rightSample = ((uint)wavData[i + 3] << 12) | ((uint)wavData[i + 2] << 4);

                            ethData[pktDataI] = (byte)((leftSample >> 16) & 0xFF);
                            ethData[pktDataI + 1] = (byte)((leftSample >> 8) & 0xFF);
                            ethData[pktDataI + 2] = (byte)(leftSample & 0xFF);

                            ethData[pktDataI + 3] = (byte)((rightSample >> 16) & 0xFF);
                            ethData[pktDataI + 4] = (byte)((rightSample >> 8) & 0xFF);
                            ethData[pktDataI + 5] = (byte)(rightSample & 0xFF);

                            ethData[pktDataI + 6] = (byte)((leftSample >> 16) & 0xFF);
                            ethData[pktDataI + 7] = (byte)((leftSample >> 8) & 0xFF);
                            ethData[pktDataI + 8] = (byte)(leftSample & 0xFF);

                            ethData[pktDataI + 9] = (byte)((rightSample >> 16) & 0xFF);
                            ethData[pktDataI + 10] = (byte)((rightSample >> 8) & 0xFF);
                            ethData[pktDataI + 11] = (byte)(rightSample & 0xFF);

                            ethData[pktDataI + 12] = (byte)((leftSample >> 16) & 0xFF);
                            ethData[pktDataI + 13] = (byte)((leftSample >> 8) & 0xFF);
                            ethData[pktDataI + 14] = (byte)(leftSample & 0xFF);

                            ethData[pktDataI + 15] = (byte)((rightSample >> 16) & 0xFF);
                            ethData[pktDataI + 16] = (byte)((rightSample >> 8) & 0xFF);
                            ethData[pktDataI + 17] = (byte)(rightSample & 0xFF);

                            pktDataI += 18;
                        }

                        ethAudio.sendAudioData(ethData, pktDataI, firstPacket);

                        // End of file?
                        if (bytesRead < wavData.Length)
                        {
                            // We don't break so that we don't call sendStop()
                            // The amp will mute when the buffer is empty
                            wavFile.Close();
                            audioThread = null;
                            return;
                        }

                        firstPacket = false;

                        /*
                         * TODO: Instead of sleeping here we could do some number crunching
                         * like the digital crossover.  If we did this, we would keep track
                         * of the length of time that the number crunching took and subtract
                         * that from the return value of getEstimatedSleepLength().
                         * 
                         * TODO: Would heavy CPU use interfere with the Windows networking code?
                         */

                        Thread.Sleep(ethAudio.getEstimatedSleepLength(ethData.Length));
                    }

                }

            }
            
            ethAudio.sendStop();

            wavFile.Close();

        }

        private void btnStop_Click(object sender, EventArgs e)
        {
            if (audioThread != null)
            {
                stopAudio = true;
                audioThread.Join();
                audioThread = null;
            }
        }

        private void btnStartTest_Click(object sender, EventArgs e)
        {
            if (!ethAudio.isAmplifierConnected())
                return;

            if (audioThread != null)
                return;

            stopAudio = false;
            chkMute.Checked = false;

            audioThread = new Thread(new ThreadStart(sendTestDataFunc));

            audioThread.Start();
        }

        private void btnPlayWav_Click(object sender, EventArgs e)
        {
            if (!ethAudio.isAmplifierConnected())
                return;

            if (audioThread != null)
                return;

            OpenFileDialog dlg = new OpenFileDialog();

            dlg.Filter = "WAV files (*.wav)|*.wav";

            if (dlg.ShowDialog(this) != DialogResult.OK)
                return;

            waveFileName = dlg.FileName;

            stopAudio = false;
            chkMute.Checked = false;

            audioThread = new Thread(new ThreadStart(sendWaveFunc));

            audioThread.Start();
        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            ethAudio.Dispose();
            stopAudio = true;
            Thread.Sleep(1000); // To give the networking code time to clean up
        }

        private void btnStartCountTest_Click(object sender, EventArgs e)
        {
            if (!ethAudio.isAmplifierConnected())
                return;

            if (audioThread != null)
                return;

            stopAudio = false;
            chkMute.Checked = false;

            audioThread = new Thread(new ThreadStart(sendCounterFunc));

            audioThread.Start();
        }

        private void btnMuteOn_Click(object sender, EventArgs e)
        {
            ethAudio.sendMuteOn();
            chkMute.Checked = true;
        }

        private void btnMuteOff_Click(object sender, EventArgs e)
        {
            ethAudio.sendMuteOff();
            chkMute.Checked = false;
        }

        private void btnPauseOn_Click(object sender, EventArgs e)
        {
            needPause = true;
        }

        private void btnPauseOff_Click(object sender, EventArgs e)
        {
            needPause = false;
        }

    }
}
