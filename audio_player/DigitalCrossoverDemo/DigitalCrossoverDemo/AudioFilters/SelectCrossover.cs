using System;

namespace AudioFilters
{
    /// <summary>
    /// Given a source that was created by the CrossoverFilter with 6 channels,
    /// this filter will select pair of channels and return only that data to
    /// the caller.
    /// </summary>
    class SelectCrossover : IAudioFilter
    {

        private IAudioFilter source;
        private int index;

        /// <summary>
        /// 
        /// </summary>
        /// <param name="source"></param>
        /// <param name="index">The channels to return, 0 for Woofer, 1 for Midrange, and 2 for Tweeter</param>
        public SelectCrossover(IAudioFilter source, int index)
        {

            if (source.NumberOfChannels != 6)
                throw new ArgumentException("source must have 6 channels, such as the CrossoverFilter");

            if (index < 0 || index >= 3)
                throw new ArgumentOutOfRangeException("index", "" + index);

            this.source = source;
            this.index = index;
        }

        public uint BitsPerSample
        {
            get
            {
                return source.BitsPerSample;
            }
        }

        public uint NumberOfChannels
        {
            get
            {
                return 2;
            }
        }

        public uint SampleRate
        {
            get
            {
                return source.SampleRate;
            }
        }

        public long Position
        {
            get
            {
                return source.Position / 3;
            }
        }

        public long Length
        {
            get
            {
                return source.Length / 3;
            }
        }

        public int read(double[] data, int offset, int count)
        {
            int lastOffset = offset;

            double[] readData = new double[count * 3];

            int nRead = source.read(readData, 0, readData.Length);

            for (int i = 0; i < nRead; i += 6)
            {
                data[lastOffset++] = readData[i + (index*2)];
                data[lastOffset++] = readData[i + (index*2) + 1];
            }

            return nRead / 3;
        }

        public void seek(long newPosition)
        {
            source.seek(newPosition * 3);
        }

        public void setSelectedChannel(int index)
        {
            if (index < 0 || index >= 3)
                throw new ArgumentOutOfRangeException("index", "" + index);

            this.index = index;
        }

    }
}
