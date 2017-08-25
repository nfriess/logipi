using System;
using System.IO;

namespace AudioFilters
{
    /// <summary>
    /// Reads raw audio samples from a file.  Can be used to read from a .wav file, although
    /// the file's header will result in garbage samples at first.
    /// </summary>
    class RawFileReader : IAudioFilter
    {

        private FileStream wavFile;

        private uint bitsPerSample;
        private uint sampleRate;
        private uint numberOfChannels;

        private long currentPosition;
        
        public RawFileReader(string filename, uint bitsPerSample, uint sampleRate, uint numberOfChannels)
        {

            if (bitsPerSample != 8 && bitsPerSample != 16 && bitsPerSample != 32)
                throw new ArgumentException("Currently only supports 8, 16, or 32 bits per sample");
            
            wavFile = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.Read);

            this.bitsPerSample = bitsPerSample;
            this.sampleRate = sampleRate;
            this.numberOfChannels = numberOfChannels;
            this.currentPosition = 0;

        }

        public uint BitsPerSample
        {
            get
            {
                return bitsPerSample;
            }
        }

        public uint NumberOfChannels
        {
            get
            {
                return numberOfChannels;
            }
        }

        public long Position
        {
            get
            {
                return currentPosition;
            }
        }

        public uint SampleRate
        {
            get
            {
                return sampleRate;
            }
        }

        public long Length
        {
            get
            {
                return wavFile.Length / (bitsPerSample / 8);
            }
        }

        public int read(double[] data, int offset, int count)
        {
            int numSamplesComplete = 0;
            int lastOffset = offset;

            byte[] fileData = new byte[count * (bitsPerSample / 8)];

            int bytesRead = wavFile.Read(fileData, 0, fileData.Length);

            for (int i = 0; i < bytesRead; i += ((int)bitsPerSample / 8))
            {

                int sample;

                if (bitsPerSample == 8)
                    sample = fileData[i];
                else if (bitsPerSample == 16)
                    sample = BitConverter.ToInt16(fileData, i);
                else if (bitsPerSample == 32)
                    sample = BitConverter.ToInt32(fileData, i);
                else
                    throw new Exception("Unknown bitsPerSample");

                data[lastOffset++] = sample;

                numSamplesComplete++;
            }

            return numSamplesComplete;

        }

        public void seek(long newPosition)
        {

            // Force an even number of channels
            newPosition = (newPosition / numberOfChannels) * numberOfChannels;

            wavFile.Seek(newPosition * (bitsPerSample / 8), SeekOrigin.Begin);
            currentPosition = newPosition;
        }

    }
}
