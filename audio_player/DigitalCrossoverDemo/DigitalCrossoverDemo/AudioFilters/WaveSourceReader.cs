using System;

using CSCore;

namespace AudioFilters
{
    /// <summary>
    /// Converts audio data from a CSCore IWaveSource into a stream of
    /// samples that other filters can then process.
    /// </summary>
    class WaveSourceReader : IAudioFilter
    {

        private IWaveSource source;

        private int inputBitsPerSample;

        public WaveSourceReader(IWaveSource source)
        {

            if (source.WaveFormat.Channels != 2)
                throw new ArgumentException("Unexpected number of channels in source, we only support stereo: " + source.WaveFormat.Channels);

            if ((source.WaveFormat is WaveFormatExtensible) && ((WaveFormatExtensible)source.WaveFormat).SubFormat != AudioSubTypes.Pcm)
                throw new ArgumentException("Can only handle PCM data");

            if (source.WaveFormat.BitsPerSample != 16 && source.WaveFormat.BitsPerSample != 24)
                throw new ArgumentException("Unexpected bits per sample, we only support 16 or 24: " + source.WaveFormat.BitsPerSample);

            this.source = source;
            this.inputBitsPerSample = source.WaveFormat.BitsPerSample;
        }

        public uint BitsPerSample
        {
            get
            {
                // We manually downconvert to 16 bit
                return 16;
            }
        }

        public uint NumberOfChannels
        {
            get
            {
                return (uint)source.WaveFormat.Channels;
            }
        }

        public uint SampleRate
        {
            get
            {
                return (uint)source.WaveFormat.SampleRate;
            }
        }

        public long Position
        {
            get
            {
                return source.Position / (source.WaveFormat.BitsPerSample / 8);
            }
        }

        public long Length
        {
            get
            {
                return source.Length / (source.WaveFormat.BitsPerSample / 8);
            }
        }

        public int read(double[] data, int offset, int count)
        {
            int lastOffset = offset;
            int numSamplesComplete = 0;

            byte[] readData = new byte[count * 2];

            int bytesRead = source.Read(readData, 0, count * 2);

            byte[] sampleBytes = new byte[4];

            for (int i = 0; i < bytesRead; i += (inputBitsPerSample / 8))
            {

                double sample;

                if (inputBitsPerSample == 16)
                    sample = BitConverter.ToInt16(readData, i);
                else if (inputBitsPerSample == 24)   //TO DO allow full 24 bit samples not reformatted to 16 bits CW
                {

                    Array.Copy(readData, i, sampleBytes, 0, 3);

                    if ((readData[i + 2] & 0x80) != 0)
                        sampleBytes[3] = 0xFF;
                    else
                        sampleBytes[3] = 0;

                    sample = BitConverter.ToInt32(sampleBytes, 0);

                    // Downsample to 16 bits
                    sample /= 256.0;

                }
                else
                    throw new Exception("Unknown BitsPerSample");

                data[lastOffset++] = sample;

                numSamplesComplete++;
            }

            return numSamplesComplete;
        }

        public void seek(long newPosition)
        {

            // Restricted to seeking to even second boundaries
            TimeSpan ts = new TimeSpan(0, 0, (int)(newPosition / source.WaveFormat.SampleRate / source.WaveFormat.Channels));

            source.SetPosition(ts);

        }
    }
}
