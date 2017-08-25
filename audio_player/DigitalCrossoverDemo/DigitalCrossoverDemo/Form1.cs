using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

using CSCore;
using CSCore.SoundOut;
using CSCore.Codecs;

using DigitalCrossover;
using AudioFilters;

namespace DigitalCrossoverDemo
{
    public partial class Form1 : Form
    {
        /// <summary>
        /// Number of samples to use when displaying time domain and frequency domain graphs
        /// </summary>
        private const int SAMPLE_LEN = 1024;

        /// <summary>
        /// First dimension is the number of channels (6) and the second dimension are the samples
        /// obtained from sampleTap
        /// </summary>
        private double[][] sampleData;

        /// <summary>
        /// CSCore sound device, set when playback starts and called to stop playbacks
        /// </summary>
        private ISoundOut soundOutDevice;

        /// <summary>
        /// References to various audio filters
        /// </summary>
        private SampleTap sampleTap;
        private IAudioFilter lastFilterStep;
        private SelectCrossover channelSelectFilter;
        private VolumeControl volumeControlFilter;

        /// <summary>
        /// Flag to avoid seeking while the user is dragging the time bar
        /// </summary>
        private bool tbarIsDragging = false;

        public Form1()
        {

            sampleData = new double[6][];
            for (int i = 0; i < sampleData.Length; i++)
                sampleData[i] = new double[SAMPLE_LEN];

            InitializeComponent();
        }

        /// <summary>
        /// An attempt at a quick method to display the distortion introduced by running
        /// the input file through the digital crossover.  Prints results in the debug
        /// console. Ideally we want any numerical errors to be less than 120dB, a
        /// level that will be inaudible.
        /// </summary>
        private void measureErrorDB(CrossoverThreeWayFilter filter, int kernelLength)
        {

            double[] filterData = new double[1024 * 10 * 6];
            double[] fileData = new double[1024 * 10 * 2];
            double[] filterSum = new double[1024 * 10 * 2];

            Dictionary<Int32, Int32> dict = new Dictionary<Int32, Int32>();

            RawFileReader rdr2 = new RawFileReader(lblFileName.Text, 16, 44100, 2);

            ConvertBitsPerSample bps2 = new ConvertBitsPerSample(rdr2, 24);

            filter.read(filterData, 0, (kernelLength / 2) * 6);


            while (true)
            {

                int nReadFilter = filter.read(filterData, 0, filterData.Length);

                if (nReadFilter == 0)
                    break;

                int nReadFile = bps2.read(fileData, 0, fileData.Length);

                if (nReadFile * 3 != nReadFilter)
                    break;
                    //throw new Exception("" + (nReadFile * 3) + "!=" + nReadFilter);

                for (int i = 0; i < nReadFilter; i += 6)
                {

                    filterSum[i / 3] = filterData[i] + filterData[i + 2] + filterData[i + 4];
                    filterSum[i / 3 + 1] = filterData[i + 1] + filterData[i + 3] + filterData[i + 5];

                }

                for (int i = 0; i < fileData.Length; i++)
                {

                    int error = (int)Math.Round(Math.Log10(Math.Abs(filterSum[i] - fileData[i]) / fileData[i]) * 20.0);

                    if (dict.ContainsKey(error))
                        dict[error]++;
                    else
                        dict.Add(error, 1);

                }



            }

            Console.Out.WriteLine("Max noise: " + dict.Keys.Max() + " dB");

            List<Int32> keys = new List<int>(dict.Keys);
            keys.Sort();

            foreach (int k in keys)
            {
                Console.Out.WriteLine("" + k + " dB: " + dict[k]);
            }

        }

        /// <summary>
        /// An attempt at a quick method to display the distortion introduced by running
        /// the input file through the digital crossover.  Prints results in the debug
        /// console. Ideally we want any numerical errors to be less than 20 bits, which
        /// is the resolution of the DACs that we use.
        /// </summary>
        private void measureErrorBits(CrossoverThreeWayFilter filter, int kernelLength)
        {

            double[] filterData = new double[1024 * 10 * 6];
            double[] fileData = new double[1024 * 10 * 2];
            double[] filterSum = new double[1024 * 10 * 2];

            Dictionary<Int32, Int32> dict = new Dictionary<Int32, Int32>();

            RawFileReader rdr2 = new RawFileReader(lblFileName.Text, 16, 44100, 2);

            ConvertBitsPerSample bps2 = new ConvertBitsPerSample(rdr2, 24);

            filter.read(filterData, 0, (kernelLength / 2) * 6);

            while (true)
            {

                int nReadFilter = filter.read(filterData, 0, filterData.Length);

                if (nReadFilter == 0)
                    break;

                int nReadFile = rdr2.read(fileData, 0, fileData.Length);

                if (nReadFile * 3 != nReadFilter)
                    break;
                //throw new Exception("" + (nReadFile * 3) + "!=" + nReadFilter);

                for (int i = 0; i < nReadFilter; i += 6)
                {

                    filterSum[i / 3] = filterData[i] + filterData[i + 2] + filterData[i + 4];
                    filterSum[i / 3 + 1] = filterData[i + 1] + filterData[i + 3] + filterData[i + 5];

                }

                for (int i = 0; i < fileData.Length; i++)
                {

                    double error = Math.Abs(filterData[i] - fileData[i]);

                    int logMag = (int)Math.Ceiling(Math.Log(error) / Math.Log(2));

                    if (logMag < 0)
                        logMag = 0;

                    if (dict.ContainsKey(logMag))
                        dict[logMag]++;
                    else
                        dict.Add(logMag, 1);

                }

            }

            List<Int32> keys = new List<int>(dict.Keys);
            keys.Sort();

            foreach (int k in keys)
            {
                Console.Out.WriteLine("" + k + ": " + dict[k]);
            }

        }

        private void button1_Click(object sender, EventArgs e)
        {

            bool normalized = false;

            Crossover crossover = Crossover.createThreeWayCrossover(Int32.Parse(txtLowerFreq.Text),
                Int32.Parse(txtUpperFreq.Text), Int32.Parse(txtLowerTrans.Text), Int32.Parse(txtUpperTrans.Text),
                44100, normalized, false, 10.0);

            RawFileReader rdr = new RawFileReader(lblFileName.Text, 16, 44100, 2);

            ConvertBitsPerSample bps = new ConvertBitsPerSample(rdr, 24);

            CrossoverThreeWayFilter filter = new CrossoverThreeWayFilter(bps, crossover);

            measureErrorBits(filter, crossover.wooferFilterKernel.Length);

        }

        private void button2_Click(object sender, EventArgs e)
        {

            bool normalized = false;

            Crossover crossover = Crossover.createThreeWayCrossover(Int32.Parse(txtLowerFreq.Text),
                Int32.Parse(txtUpperFreq.Text), Int32.Parse(txtLowerTrans.Text), Int32.Parse(txtUpperTrans.Text),
                44100, normalized, false, 10.0);

            RawFileReader rdr = new RawFileReader(lblFileName.Text, 16, 44100, 2);

            ConvertBitsPerSample bps = new ConvertBitsPerSample(rdr, 24);

            CrossoverThreeWayFilter filter = new CrossoverThreeWayFilter(bps, crossover);

            measureErrorDB(filter, crossover.wooferFilterKernel.Length);

        }

        private void btnOpenFile_Click(object sender, EventArgs e)
        {

            OpenFileDialog dlg = new OpenFileDialog();
            dlg.ShowDialog();

            lblFileName.Text = dlg.FileName;

        }

        private void btnPlay_Click(object sender, EventArgs e)
        {

            IAudioFilter waveRdr;

            // For the purposes of testing we process .raw files as
            // containing 16-bit stereo PCM data at 44.1KHz.  This is much
            // like a .wav file but without the header.
            if (lblFileName.Text.EndsWith(".raw"))
            {
                waveRdr = new RawFileReader(lblFileName.Text, 16, 44100, 2);
            }
            else
            {
                IWaveSource inputFile = CodecFactory.Instance.GetCodec(lblFileName.Text);

                waveRdr = new WaveSourceReader(inputFile);
            }

            // Convert to 24 bit samples (if needed)
            ConvertBitsPerSample bpsConvert = new ConvertBitsPerSample(waveRdr, 24);

            // Create a crossover and catch any errors in case the frequency parameters
            // are not valid
            Crossover crossover;

            try
            {
                crossover = Crossover.createThreeWayCrossover(Int32.Parse(txtLowerFreq.Text),
                    Int32.Parse(txtUpperFreq.Text), Int32.Parse(txtLowerTrans.Text), Int32.Parse(txtUpperTrans.Text),
                    waveRdr.SampleRate, true, false, 10.0);
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "Error building crossover: " + ex.Message);
                return;
            }

            // Start creating filters...
            CrossoverThreeWayFilter filter = new CrossoverThreeWayFilter(bpsConvert, crossover);

            sampleTap = new SampleTap(filter, SAMPLE_LEN);



            int crossoverIdx = 1;
            if (rdoPlayWoofer.Checked)
                crossoverIdx = 0;
            else if (rdoPlayMidrange.Checked)
                crossoverIdx = 1;
            else if (rdoPlayTweeter.Checked)
                crossoverIdx = 2;

            channelSelectFilter = new SelectCrossover(sampleTap, crossoverIdx);

            volumeControlFilter = new VolumeControl(channelSelectFilter);

            // Only needed for playback through Windows
            lastFilterStep = new ConvertBitsPerSample(volumeControlFilter, 16);

            // Done creating filters...



            tbarFilePosition.Value = 0;
            // Max in seconds
            tbarFilePosition.Maximum = (int)(lastFilterStep.Length / lastFilterStep.SampleRate / lastFilterStep.NumberOfChannels);
            tbarFilePosition.Enabled = true;


            // Playback through Windows
            IWaveSource finalWaveSource = new FilterToWaveSource(lastFilterStep);

            //_soundOut = new WasapiOut();
            soundOutDevice = new WaveOut();
            soundOutDevice.Initialize(finalWaveSource);
            soundOutDevice.Play();

            tmrUpdateViz.Start();

        }

        private void btnStop_Click(object sender, EventArgs e)
        {
            soundOutDevice.Stop();
            tmrUpdateViz.Stop();
            tbarFilePosition.Enabled = false;
            lastFilterStep = null;
        }

        private void tmrUpdateViz_Tick(object sender, EventArgs e)
        {

            if (lastFilterStep != null && !tbarIsDragging)
            {
                // Position in seconds
                long newValue = lastFilterStep.Position / lastFilterStep.SampleRate / lastFilterStep.NumberOfChannels;
                if (newValue > tbarFilePosition.Maximum)
                    newValue = tbarFilePosition.Maximum;
                tbarFilePosition.Value = (int)newValue;
            }

            if (sampleTap != null)
            {
                for (int i = 0; i < sampleData.Length; i++)
                {
                    sampleTap.getSamples(i, sampleData[i]);
                }
            }

            picWaveLeftWoofer.Refresh();
            picWaveRightWoofer.Refresh();
            picWaveLeftMidrange.Refresh();
            picWaveRightMidrange.Refresh();
            picWaveLeftTweeter.Refresh();
            picWaveRightTweeter.Refresh();

            picFreqLeftWoofer.Refresh();
            picFreqRightWoofer.Refresh();
            picFreqLeftMidrange.Refresh();
            picFreqRightMidrange.Refresh();
            picFreqLeftTweeter.Refresh();
            picFreqRightTweeter.Refresh();

        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (soundOutDevice != null && soundOutDevice.PlaybackState == PlaybackState.Playing)
            {
                btnStop_Click(null, null);
            }
        }

        private void drawWave(PictureBox pBox, PaintEventArgs e, int channelNum)
        {

            e.Graphics.FillRegion(Brushes.Black, new Region(new Rectangle(0, 0, pBox.Width, pBox.Height)));

            if (sampleTap == null || !chkDrawWaves.Checked)
                return;

            int xScale = (int)Math.Ceiling((double)sampleData[channelNum].Length / (double)pBox.Width);

            Point[] drawPts = new Point[sampleData[channelNum].Length / xScale];

            int maxBits = (int)sampleTap.BitsPerSample;

            for (int i = 0; i < drawPts.Length && i * xScale < sampleData[channelNum].Length; i++)
            {

                double y = (sampleData[channelNum][i * xScale] + (1 << (maxBits-1))) / (1 << maxBits) * pBox.Height;


                drawPts[i] = new Point(i, (int)Math.Floor(y));

            }


            e.Graphics.DrawLines(Pens.White, drawPts);
        }

        private void drawFFT(PictureBox pBox, PaintEventArgs e, int channelNum)
        {

            e.Graphics.FillRegion(Brushes.Black, new Region(new Rectangle(0, 0, pBox.Width, pBox.Height)));

            if (sampleTap == null || !chkDrawFFTs.Checked)
                return;

            Complex[] fft = new Complex[sampleData[channelNum].Length];

            for (int i = 0; i < sampleData[channelNum].Length; i++)
            {
                fft[i] = sampleData[channelNum][i];
            }

            FourierAnalysis.complexUnscaledFFT(fft);

            Point[] drawPts = new Point[fft.Length / 2];

            for (int i = 0; i < drawPts.Length && i * 2 < fft.Length; i++)
            {

                double magnitude = 20;

                if (sampleTap.BitsPerSample == 24)
                    magnitude = 15;

                try
                {
                    magnitude *= Math.Log10(Math.Sqrt(fft[i].Real * fft[i].Real + fft[i].Imaginary * fft[i].Imaginary));
                }
                catch (OverflowException)
                {
                    magnitude = 0;
                }

                if (magnitude > pBox.Height || Double.IsInfinity(magnitude) || Double.IsNaN(magnitude))
                    magnitude = pBox.Height;

                double y = pBox.Height - magnitude;

                drawPts[i] = new Point(i, (int)Math.Floor(y));
            }


            e.Graphics.DrawLines(Pens.White, drawPts);
        }

        private void picWaveLeftWoofer_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 0);
        }

        private void picWaveRightWoofer_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 1);
        }

        private void picWaveLeftMidrange_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 2);
        }

        private void picWaveRightMidrange_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 3);
        }

        private void picWaveLeftTweeter_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 4);
        }

        private void picWaveRightTweeter_Paint(object sender, PaintEventArgs e)
        {
            drawWave((PictureBox)sender, e, 5);
        }

        private void picFreqLeftWoofer_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 0);
        }

        private void picFreqRightWoofer_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 1);
        }

        private void picFreqLeftMidrange_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 2);
        }

        private void picFreqRightMidrange_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 3);
        }

        private void picFreqLeftTweeter_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 4);
        }

        private void picFreqRightTweeter_Paint(object sender, PaintEventArgs e)
        {
            drawFFT((PictureBox)sender, e, 5);
        }




        private void tbarFilePosition_Scroll(object sender, EventArgs e)
        {
            if (lastFilterStep != null && soundOutDevice != null)
            {
                soundOutDevice.Stop();
                lastFilterStep.seek((long)tbarFilePosition.Value * (long)lastFilterStep.SampleRate * (long)lastFilterStep.NumberOfChannels);
                soundOutDevice.Play();
            }
        }

        private void tbarFilePosition_MouseDown(object sender, MouseEventArgs e)
        {
            tbarIsDragging = true;
        }

        private void tbarFilePosition_MouseUp(object sender, MouseEventArgs e)
        {
            tbarIsDragging = false;
        }



        private void tbarVolume_Scroll(object sender, EventArgs e)
        {
            volumeControlFilter.setVolume((double)tbarVolume.Value / (double)tbarVolume.Maximum);
        }




        private void rdoPlayWoofer_CheckedChanged(object sender, EventArgs e)
        {
            if (soundOutDevice != null && channelSelectFilter != null && rdoPlayWoofer.Checked)
            {
                soundOutDevice.Stop();
                channelSelectFilter.setSelectedChannel(0);
                soundOutDevice.Play();
            }
        }

        private void rdoPlayMidrange_CheckedChanged(object sender, EventArgs e)
        {
            if (soundOutDevice != null && channelSelectFilter != null && rdoPlayMidrange.Checked)
            {
                soundOutDevice.Stop();
                channelSelectFilter.setSelectedChannel(1);
                soundOutDevice.Play();
            }
        }

        private void rdoPlayTweeter_CheckedChanged(object sender, EventArgs e)
        {
            if (soundOutDevice != null && channelSelectFilter != null && rdoPlayTweeter.Checked)
            {
                soundOutDevice.Stop();
                channelSelectFilter.setSelectedChannel(2);
                soundOutDevice.Play();
            }
        }

    }
}
