using System;

namespace AudioFilters
{
    /// <summary>
    /// Implements a volume control, either per-channel or on all channels.
    /// </summary>
    class VolumeControl : IAudioFilter
    {
        private IAudioFilter source;
        private uint numberOfChannels;
        private double[] volume;

        public VolumeControl(IAudioFilter source)
        {
            this.source = source;

            this.numberOfChannels = source.NumberOfChannels;

            this.volume = new double[this.numberOfChannels];

            for (int i = 0; i < this.volume.Length; i++)
            {
                this.volume[i] = 1.0;
            }

        }

        public VolumeControl(IAudioFilter source, double startingVolume, double leftBassAdjust, double leftMidAdjust, double leftMidUpperAdjust, double leftTrebAdjust, double rightBassAdjust, double rightMidAdjust, double rightMidUpperAdjust, double rightTrebAdjust)
        {
            this.source = source;

            this.numberOfChannels = source.NumberOfChannels;

            this.volume = new double[this.numberOfChannels];

            for (int i = 0; i < this.volume.Length; i++)  //volume[0] = LW; volume[1] = RW; volume[2] = LML; volume[3] = RML; volume[4] = LMU; volume[5] = RMU; volume[6] = LT; volume[7] = RT
            {
                volume[0] = startingVolume * leftBassAdjust;
                volume[1] = startingVolume * rightBassAdjust;
                volume[2] = startingVolume * leftMidAdjust;
                volume[3] = startingVolume * rightMidAdjust;
                volume[4] = startingVolume * leftMidUpperAdjust;
                volume[5] = startingVolume * rightMidUpperAdjust;
                volume[6] = startingVolume * leftTrebAdjust;
                volume[7] = startingVolume * rightTrebAdjust;
            }

        }

        public uint BitsPerSample
        {
            get
            {
                return source.BitsPerSample;
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
                return numberOfChannels;
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

            for (int i = 0; i < nRead; i += (int)numberOfChannels)
            {

                for (int j = 0; j < numberOfChannels; j++)
                {
                    data[i + j + offset] *= volume[j];
                }
                
            }

            return nRead;
        }

        public void seek(long newPosition)
        {
            source.seek(newPosition);
        }

        /// <summary>
        /// Set the volume for all channels.
        /// </summary>
        /// <param name="volume">A value between 0 and 1.0.</param>
        public void setVolume(double volume)
        {

            if (volume < 0 || volume > 1.0)
                throw new ArgumentOutOfRangeException("volume", "" + volume, "Must be between 0 and 1");

            for (int i = 0; i < this.volume.Length; i++)
            {
                this.volume[i] = volume;
            }

        }

        /// <summary>
        /// Set the volume on a specific channel.
        /// </summary>
        /// <param name="channel">The channel number.</param>
        /// <param name="volume">A value between 0 and 1.0.</param>
        public void setVolumePerChannel(int channel, double volume)
        {

            if (channel < 0 || channel >= numberOfChannels)
                throw new ArgumentOutOfRangeException("channel", "" + channel);

            if (volume < 0 || volume > 1.0)
                throw new ArgumentOutOfRangeException("volume", "" + volume, "Must be between 0 and 1.0");

            this.volume[channel] = volume;
        }

    }
}
