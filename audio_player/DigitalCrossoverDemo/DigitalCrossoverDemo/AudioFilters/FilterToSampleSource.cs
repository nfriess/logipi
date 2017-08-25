using CSCore;


namespace AudioFilters
{
    class FilterToSampleSource : ISampleSource
    {

        private IAudioFilter source;

        public FilterToSampleSource(IAudioFilter source)
        {
            this.source = source;
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
                return source.Length;
            }
        }

        public long Position
        {
            get
            {
                return source.Position;
            }

            set
            {
                this.source.seek((uint)value);
            }
        }

        public WaveFormat WaveFormat
        {
            get
            {
                WaveFormat fmt = new WaveFormat((int)source.SampleRate, 16, (int)source.NumberOfChannels);
                return fmt;
            }
        }

        public void Dispose()
        {
            //
        }

        public int Read(float[] buffer, int offset, int count)
        {

            double[] readBuffer = new double[count];

            int nRead = source.read(readBuffer, 0, count);

            for (int i = 0; i < nRead; i++)
            {
                // CSCore expects this to be normalized to 0 to -1
                buffer[offset + i] = (float)readBuffer[i] / 32768f;
            }

            return nRead;
        }
    }
}
