
namespace AudioFilters
{

    /// <summary>
    /// Basic interface for any audio filter in the filter chain.
    /// </summary>
    interface IAudioFilter
    {

        /// <summary>
        /// The bits of data per sample (e.g. 16, 24).
        /// </summary>
        uint BitsPerSample
        {
            get;
        }

        /// <summary>
        /// Sample rate of the audio source (e.g. 44100, 48000, etc).
        /// </summary>
        uint SampleRate
        {
            get;
        }

        /// <summary>
        /// Number of channels (e.g. 1 for mono, 2 for stereo, 6 for filtered stereo).
        /// </summary>
        uint NumberOfChannels
        {
            get;
        }

        /// <summary>
        /// Current position in the input source, measured as the number of samples.
        /// </summary>
        long Position
        {
            get;
        }

        /// <summary>
        /// Length of the input source, measured as the number of samples.
        /// </summary>
        long Length
        {
            get;
        }

        /// <summary>
        /// Move to the given position in the input source.
        /// </summary>
        /// <param name="newPosition">The position as the number of samples.  Filters may
        /// impose restrictions on this value such as ensuring that the calle can only seek
        /// to an even number of channels.</param>
        void seek(long newPosition);

        /// <summary>
        /// Read the next set of samples from the filter.
        /// </summary>
        /// <param name="data">An array of samples to store the results in.</param>
        /// <param name="offset">The offset into data to start storing samples.</param>
        /// <param name="count">The number of samples to store in data.</param>
        /// <returns>The number of samples stored into data, between 0 and count.  If no
        /// more data is available (such as end of file) then this method will return 0.</returns>
        int read(double[] data, int offset, int count);


    }
}
