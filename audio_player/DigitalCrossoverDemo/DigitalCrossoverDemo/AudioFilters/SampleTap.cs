using System;

namespace AudioFilters
{
    /// <summary>
    /// Passes the samples from the source to the caller unchanged.  Keeps a copy of
    /// the last set of samples so that they can be displayed visually or otherwise
    /// analyized while the audio stream is processed.
    /// </summary>
    class SampleTap : IAudioFilter
    {

        private IAudioFilter source;
        private uint numChannels;

        private double[][] samplesSaved;

        public SampleTap(IAudioFilter source, int numSamplesToSave)
        {
            this.source = source;

            this.numChannels = source.NumberOfChannels;

            this.samplesSaved = new double[this.numChannels][];
            for (int i = 0; i < this.samplesSaved.Length; i++) {
                this.samplesSaved[i] = new double[numSamplesToSave];
            }
            
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
                return numChannels;
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
                return source.Position;
            }
        }

        public long Length
        {
            get
            {
                return source.Length;
            }
        }

        public int read(double[] data, int offset, int count)
        {

            int nRead = source.read(data, offset, count);

            if (nRead == 0)
            {
                // Clear all samples at end of stream
                for (int channel = 0; channel < samplesSaved.Length; channel++)
                {
                    Array.Clear(samplesSaved[channel], 0, samplesSaved[channel].Length);

                }
                return nRead;
            }

            if (nRead > samplesSaved[0].Length * numChannels)
            {

                for (int i = 0; i < samplesSaved[0].Length * numChannels; i += (int)numChannels)
                {
                    for (int channel = 0; channel < samplesSaved.Length; channel++)
                    {
                        samplesSaved[channel][i / numChannels] = data[offset + i + channel];
                    }
                }

            }
            else
            {
                // TODO: Untested...
                for (int channel = 0; channel < samplesSaved.Length; channel++)
                {
                    Array.Copy(samplesSaved[channel], samplesSaved[channel].Length - nRead, samplesSaved[channel], 0, samplesSaved[channel].Length - nRead);
                }

                for (int i = 0; i < nRead; i += (int)numChannels)
                {
                    for (int channel = 0; channel < samplesSaved.Length; channel++)
                    {
                        samplesSaved[channel][i + samplesSaved.Length - nRead] = data[offset + i + channel];
                    }
                }

            }

            return nRead;

        }

        public void seek(long newPosition)
        {
            source.seek(newPosition);

            // Clear all saved samples after seeking
            for (int i = 0; i < samplesSaved.Length; i++)
            {
                Array.Clear(samplesSaved[i], 0, samplesSaved[i].Length);
            }
        }


        public void getSamples(int channel, double[] sampleReturn)
        {
            if (channel < 0 || channel >= samplesSaved.Length)
                throw new ArgumentOutOfRangeException("channel", "" + channel);

            if (sampleReturn.Length != samplesSaved[0].Length)
                throw new ArgumentException("samplesSaved.Length must be " + samplesSaved.Length);

            Array.Copy(samplesSaved[channel], sampleReturn, samplesSaved[channel].Length);
        }

    }
}
