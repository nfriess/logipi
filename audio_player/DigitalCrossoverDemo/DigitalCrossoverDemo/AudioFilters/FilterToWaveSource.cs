using CSCore;
using System;

namespace AudioFilters
{
    /// <summary>
    /// Reads data from an IAudioFilter and implements an CSCore.IWaveSource so that the audio
    /// data can be played in Windows using the CSCore library.
    /// </summary>
    class FilterToWaveSource : IWaveSource
    {

        private IAudioFilter source;

        public FilterToWaveSource(IAudioFilter source)
        {
            this.source = source;

            if (source.BitsPerSample != 16)
                throw new ArgumentException("Only support 16 bits per sample");

            if (source.NumberOfChannels != 2)
                throw new ArgumentException("Only support 2 channels (stereo)");

        }

        public bool CanSeek
        {
            get
            {
                return true;
            }
        }

        public long Length
        {
            get
            {
                // CSCore seems to implement this as the number of bytes
                return source.Length * (source.BitsPerSample / 8);
            }
        }

        public long Position
        {
            get
            {
                // CSCore seems to implement this as the number of bytes
                return source.Position * (source.BitsPerSample / 8);
            }

            set
            {
                this.source.seek((uint)value / (source.BitsPerSample / 8));
            }
        }

        public WaveFormat WaveFormat
        {
            get
            {
                WaveFormat fmt = new WaveFormat((int)source.SampleRate, (int)source.BitsPerSample, (int)source.NumberOfChannels);
                return fmt;
            }
        }

        public void Dispose()
        {
            //
        }

        public int Read(byte[] buffer, int offset, int count)
        {

            if ((count % 2) != 0)
                throw new ArgumentException("count must be even");

            double[] readBuffer = new double[count / 2];
            int nReturn = 0;

            int nRead = source.read(readBuffer, 0, readBuffer.Length);

            for (int i = 0; i < readBuffer.Length; i++)
            {
                short sample = (short)Math.Round(readBuffer[i]);

                byte[] bits = BitConverter.GetBytes(sample);

                buffer[nReturn + offset] = bits[0];
                nReturn++;

                buffer[nReturn + offset] = bits[1];
                nReturn++;

            }

            return nReturn;
        }

    }
}
