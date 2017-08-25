using System;

namespace AudioFilters
{
    /// <summary>
    /// Takes any input stream type (2, 6, or 8 channels) and expands the bits per sample
    /// to targetBPS.  Can be used to convert 16-bit samples to 24-bit, for example, before
    /// processing them with the digital crossover.
    /// </summary>
    class ConvertBitsPerSample : IAudioFilter
    {

        private IAudioFilter source;
        private uint targetBPS;
        private double multiplier;

        public ConvertBitsPerSample(IAudioFilter source, uint targetBPS)
        {

            if (targetBPS != 16 && targetBPS != 24 && targetBPS != 32)
                throw new ArgumentException("targetBPS must be either 16, 24, or 32");

            this.source = source;
            this.targetBPS = targetBPS;

            if (targetBPS > source.BitsPerSample)
                multiplier = 1 << ((int)targetBPS - (int)source.BitsPerSample);
            else
                multiplier = 1.0 / (1 << ((int)source.BitsPerSample - (int)targetBPS));

        }


        public uint BitsPerSample
        {
            get
            {
                return targetBPS;
            }
        }

        public long Length
        {
            get
            {
                return source.Length;
            }
        }

        public uint NumberOfChannels
        {
            get
            {
                return source.NumberOfChannels;
            }
        }

        public long Position
        {
            get
            {
                return source.Position;
            }
        }

        public uint SampleRate
        {
            get
            {
                return source.SampleRate;
            }
        }

        public int read(double[] data, int offset, int count)
        {

            int nRead = source.read(data, offset, count);

            for (int i = 0; i < nRead; i++)
            {
                data[i + offset] *= multiplier;
            }

            return nRead;

        }

        public void seek(long newPosition)
        {
            source.seek(newPosition);
        }
    }
}
