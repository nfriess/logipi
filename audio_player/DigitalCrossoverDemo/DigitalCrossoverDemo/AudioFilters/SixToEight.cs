using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AudioFilters
{
    /// <summary>
    /// Expands 6 channel audio, like the output from CrossoverThreeWayFilter into 8 channel audio,
    /// like the output in CrossoverFourWayFilter
    /// </summary>
    class SixToEight : IAudioFilter
    {

        private IAudioFilter source;

        public SixToEight(IAudioFilter source)
        {

            if (source.NumberOfChannels != 6)
                throw new ArgumentException("source must have 6 channels, such as the CrossoverThreewayFilter");

            this.source = source;
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
                return 8;
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
                return source.Position / 4 * 3;
            }
        }

        public long Length
        {
            get
            {
                return source.Length / 4 * 3;
            }
        }

        public int read(double[] data, int offset, int count)
        {
            int lastOffset = offset;

            double[] readData = new double[count / 4 * 3];

            int nRead = source.read(readData, 0, readData.Length);

            for (int i = 0; i < nRead; i += 6)
            {

                data[lastOffset++] = readData[i];
                data[lastOffset++] = readData[i + 1];

                data[lastOffset++] = readData[i + 2];
                data[lastOffset++] = readData[i + 3];

                data[lastOffset++] = readData[i + 2];
                data[lastOffset++] = readData[i + 3];

                data[lastOffset++] = readData[i + 4];
                data[lastOffset++] = readData[i + 5];
            }

            return nRead / 3 * 4;
        }

        public void seek(long newPosition)
        {
            source.seek(newPosition / 4 * 3);
        }

    }
}
