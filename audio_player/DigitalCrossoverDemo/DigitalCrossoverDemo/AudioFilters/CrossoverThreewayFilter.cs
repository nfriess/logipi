using System;
using System.Numerics;

using DigitalCrossover;
using System.Diagnostics;

namespace AudioFilters
{
    /// <summary>
    /// Implements the digital crossover, splitting 2 audio channels into 6.
    /// </summary>
    class CrossoverThreeWayFilter : IAudioFilter
    {

        private enum States
        {
            /// <summary>
            /// The default state, where we read data from the source, perform
            /// the convolution, and return the results to the caller.
            /// </summary>
            Normal,
            /// <summary>
            /// When the source has returned only partial data, probably indicating
            /// that it has reached the end of input.
            /// </summary>
            LastReadIncomplete,
            /// <summary>
            /// When the source has run out of data but we still need to return
            /// the data from the overlap buffer to the caller.
            /// </summary>
            LastOverlapBuffer,
            /// <summary>
            /// We have returned all of the source data and all of the overlap
            /// data to the caller.  Really at the end of input.
            /// </summary>
            EndOfInput
        };

        private IAudioFilter source;
        private Crossover crossover;

        private States currentState;

        private int inputSegmentSize;

        private Complex[] H_woofer;
        private Complex[] H_midrange;
        private Complex[] H_tweeter;

        private Complex[] bufferLeftWoofer;
        private Complex[] bufferLeftMidrange;
        private Complex[] bufferLeftTweeter;
        private Complex[] bufferRightWoofer;
        private Complex[] bufferRightMidrange;
        private Complex[] bufferRightTweeter;

        private Complex[] overlapLeftWoofer;
        private Complex[] overlapLeftMidrange;
        private Complex[] overlapLeftTweeter;
        private Complex[] overlapRightWoofer;
        private Complex[] overlapRightMidrange;
        private Complex[] overlapRightTweeter;


        private long lastOverallPosition;
        private int lastInputBufferPosition;


        public CrossoverThreeWayFilter(IAudioFilter source, Crossover crossover)
        {

            if (source.NumberOfChannels != 2)
                throw new ArgumentException("Audio source must have 2 channels", "source");

            if (source.SampleRate != crossover.sampleRate)
                throw new ArgumentException("Crossover sample rate does not match input source", "crossover");

            if (crossover.crossoverType != Crossover.CROSSOVER_TYPES.THREE_WAY)
                throw new ArgumentException("Crossover must be a THREE_WAY type", "crossover");

            this.source = source;
            this.crossover = crossover;

            this.currentState = States.Normal;

            this.lastOverallPosition = 0;
            this.lastInputBufferPosition = -1;

            initializeFilterKernels();

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
                return 6;
            }
        }

        public long Position
        {
            get
            {
                return lastOverallPosition;
            }
        }

        public uint SampleRate
        {
            get
            {
                return source.SampleRate;
            }
        }

        public long Length
        {
            get
            {
                return source.Length * 3;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createUnscaledH
        //
        //  Arguments:      h:           The impulse response.
        //                  fftSize:     The size of the complex vector that will be
        //                               created.
        //
        //  Returns:        A pointer to a newly-allocated vector containing the
        //                  complex spectrum of h.
        //
        //  Description:    This function takes h, an arbitrary impulse response (filter
        //                  kernel), and creates H, the complex spectrum of h. The
        //                  spectrum is put into a complex vector with the length
        //                  of fftSize. If needed, this vector is zero-padded. This
        //                  function creates the unscaled version of H.
        //
        ////////////////////////////////////////////////////////////////////////////////
        private Complex[] createUnscaledH(double[] h, int fftSize)
        {
            // Make sure we have a valid pointer argument
            if (h == null)
                throw new ArgumentNullException("h");

            // Make sure the fft size is as big or bigger than the h vector size
            if (fftSize < h.Length)
                throw new ArgumentOutOfRangeException("h.Length", "" + h.Length);

            // Create the H buffer to hold the FFT of h
            Complex[] H = new Complex[fftSize];

            // Copy h[] into H[] vector, converting from real numbers to complex.
            // Zero padding is already done, since the H vector is filled with zeros
            // when it is created.
            for (int i = 0; i < h.Length; i++)
                H[i] = h[i];

            // Do an in-place unscaled FFT on h, to give H
            FourierAnalysis.complexUnscaledFFT(H);

            // Return a pointer to the newly created complex H vector
            return H;
        }

        /// <summary>
        /// Initializes all of the internal state based on the input crossover.
        /// </summary>
        private void initializeFilterKernels()
        {

            // Find the length of the filter kernels. We use the length of the woofer
            // kernel, but all 3 kernels should be exactly the sample length.
            int filterKernelLength = crossover.wooferFilterKernel.Length;

            // Calculate the size of the FFT. Take the length of the filter kernel
            // and double it, and then find the next power of 2. This will be the size
            // of the buffer that holds the zero-padded x/X/Y/y segments, and of
            // the H buffers.
            int fftSize = Utility.nextPowerOf2(filterKernelLength * 2);

            // Calculate the size of the input segment
            inputSegmentSize = fftSize - filterKernelLength + 1;

            // Calculate the size of the overlap
            int overlapSize = fftSize - inputSegmentSize;

            H_woofer = createUnscaledH(crossover.wooferFilterKernel, fftSize);
            H_midrange = createUnscaledH(crossover.midrangeFilterKernel, fftSize);
            H_tweeter = createUnscaledH(crossover.tweeterFilterKernel, fftSize);

            // Create the buffers that hold the six x/X/Y/y segments
            bufferLeftWoofer = new Complex[fftSize];
            bufferLeftMidrange = new Complex[fftSize];
            bufferLeftTweeter = new Complex[fftSize];
            bufferRightWoofer = new Complex[fftSize];
            bufferRightMidrange = new Complex[fftSize];
            bufferRightTweeter = new Complex[fftSize];

            // Create the buffers that hold the six overlap segments. These buffers
            // are initially filled with zeros.
            overlapLeftWoofer = new Complex[overlapSize];
            overlapLeftMidrange = new Complex[overlapSize];
            overlapLeftTweeter = new Complex[overlapSize];
            overlapRightWoofer = new Complex[overlapSize];
            overlapRightMidrange = new Complex[overlapSize];
            overlapRightTweeter = new Complex[overlapSize];

        }

        /// <summary>
        /// Performs the convolution on the next input segment.
        /// </summary>
        private void performNextConvolve()
        {

            // We only do the convolution when in the normal state
            if (currentState != States.Normal && currentState != States.LastReadIncomplete)
                throw new Exception("Can only be called when in the Normal or LastReadIncomplete state");

            double[] sourceData = new double[inputSegmentSize * source.NumberOfChannels];

            // Read frames from audio source
            int framesRead = source.read(sourceData, 0, sourceData.Length);

            if (framesRead == 0)
            {
                // If we previously had an incomplete read and now we are EOF, then we are EOF
                if (currentState == States.LastReadIncomplete)
                {
                    currentState = States.EndOfInput;
                    return;
                }

                // TODO: The above if is still not right.  We really should remember framesRead from the
                // final read and then return part of the overlap buffer to complete one final read...
                // ... I think...

                // Otherwise if the last read was complete and EOF lines up with the buffers, then
                // overlap contains the last bit of data
                Array.Copy(overlapLeftWoofer, 0, bufferLeftWoofer, 0, overlapLeftWoofer.Length);
                Array.Copy(overlapLeftMidrange, 0, bufferLeftMidrange, 0, overlapLeftMidrange.Length);
                Array.Copy(overlapLeftTweeter, 0, bufferLeftTweeter, 0, overlapLeftTweeter.Length);
                Array.Copy(overlapRightWoofer, 0, bufferRightWoofer, 0, overlapRightWoofer.Length);
                Array.Copy(overlapRightMidrange, 0, bufferRightMidrange, 0, overlapRightMidrange.Length);
                Array.Copy(overlapRightTweeter, 0, bufferRightTweeter, 0, overlapRightTweeter.Length);

                currentState = States.LastOverlapBuffer;
                return;
            }

            if (framesRead < 0 || framesRead > sourceData.Length)
                throw new Exception("Audio source returned unexpected number of samples: " + framesRead);

            if ((framesRead % source.NumberOfChannels) != 0)
                throw new Exception("Audio source returned uneven number of samples");

            if (framesRead < sourceData.Length)
                currentState = States.LastReadIncomplete;

            // Copy source data into left and right structures
            for (int i = 0; i < framesRead; i += 2)
            {
                bufferLeftWoofer[i / 2] = sourceData[i];
                bufferRightWoofer[i / 2] = sourceData[i + 1];
            }

            framesRead /= 2;

            // Pad remaining part of these two buffers with zeros
            Array.Clear(bufferLeftWoofer, framesRead, bufferLeftWoofer.Length - framesRead);
            Array.Clear(bufferRightWoofer, framesRead, bufferRightWoofer.Length - framesRead);

            // Do an in-place unscaled FFT on the two buffers, giving us the
            // spectra X of the stereo input signals (i.e. X_left and X_right)
            FourierAnalysis.complexUnscaledFFT(bufferLeftWoofer);
            FourierAnalysis.complexUnscaledFFT(bufferRightWoofer);

            // Copy the left and right spectra into the midrange and tweeter
            // buffers. Once this is done, we will have X_left in three buffers
            // (channels) and X_right the other three buffers.
            Array.Copy(bufferLeftWoofer, bufferLeftMidrange, bufferLeftWoofer.Length);
            Array.Copy(bufferLeftWoofer, bufferLeftTweeter, bufferLeftWoofer.Length);
            Array.Copy(bufferRightWoofer, bufferRightMidrange, bufferRightWoofer.Length);
            Array.Copy(bufferRightWoofer, bufferRightTweeter, bufferRightWoofer.Length);

            // Do the point-by-point complex multiply of H times X, which yields Y
            for (int i = 0; i < bufferLeftWoofer.Length; i++)
            {
                bufferLeftWoofer[i] *= H_woofer[i];
                bufferLeftMidrange[i] *= H_midrange[i];
                bufferLeftTweeter[i] *= H_tweeter[i];

                bufferRightWoofer[i] *= H_woofer[i];
                bufferRightMidrange[i] *= H_midrange[i];
                bufferRightTweeter[i] *= H_tweeter[i];
            }

            // Do an in-place scaled IFFT on the six buffers containing Y,
            // to yield 6 channels of y
            FourierAnalysis.complexScaledIFFT(bufferLeftWoofer);
            FourierAnalysis.complexScaledIFFT(bufferLeftMidrange);
            FourierAnalysis.complexScaledIFFT(bufferLeftTweeter);
            FourierAnalysis.complexScaledIFFT(bufferRightWoofer);
            FourierAnalysis.complexScaledIFFT(bufferRightMidrange);
            FourierAnalysis.complexScaledIFFT(bufferRightTweeter);

            // Add the contents of the overlap buffers to the first part of the
            // y buffers
            for (int i = 0; i < overlapLeftWoofer.Length; i++)
            {
                bufferLeftWoofer[i] += overlapLeftWoofer[i];
                bufferLeftMidrange[i] += overlapLeftMidrange[i];
                bufferLeftTweeter[i] += overlapLeftTweeter[i];
                bufferRightWoofer[i] += overlapRightWoofer[i];
                bufferRightMidrange[i] += overlapRightMidrange[i];
                bufferRightTweeter[i] += overlapRightTweeter[i];
            }

            Array.Copy(bufferLeftWoofer, inputSegmentSize, overlapLeftWoofer, 0, overlapLeftWoofer.Length);
            Array.Copy(bufferLeftMidrange, inputSegmentSize, overlapLeftMidrange, 0, overlapLeftMidrange.Length);
            Array.Copy(bufferLeftTweeter, inputSegmentSize, overlapLeftTweeter, 0, overlapLeftTweeter.Length);
            Array.Copy(bufferRightWoofer, inputSegmentSize, overlapRightWoofer, 0, overlapRightWoofer.Length);
            Array.Copy(bufferRightMidrange, inputSegmentSize, overlapRightMidrange, 0, overlapRightMidrange.Length);
            Array.Copy(bufferRightTweeter, inputSegmentSize, overlapRightTweeter, 0, overlapRightTweeter.Length);

            return;

        }


        public int read(double[] data, int offset, int count)
        {
            int numSamplesComplete = 0;
            int lastOffset = offset;


            if ((count % this.NumberOfChannels) != 0)
                throw new ArgumentException("count must be a multiple of " + this.NumberOfChannels);

            // We are out of input and overlap buffer
            if (currentState == States.EndOfInput)
                return 0;


            while (numSamplesComplete < count)
            {

                if (lastInputBufferPosition < 0 || lastInputBufferPosition >= inputSegmentSize)
                {

                    // We were in the last overlap buffer and now we are out of data
                    if (currentState == States.LastOverlapBuffer)
                    {
                        currentState = States.EndOfInput;
                        break;
                    }

                    // We are in the normal state, so process some more data
                    performNextConvolve();

                    // If the above call decided we are at EOF then quit
                    if (currentState == States.EndOfInput)
                    {
                        break;
                    }

                    lastInputBufferPosition = 0;
                }

                data[lastOffset++] = bufferLeftWoofer[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferRightWoofer[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferLeftMidrange[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferRightMidrange[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferLeftTweeter[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferRightTweeter[lastInputBufferPosition].Real;

                lastInputBufferPosition++;

                numSamplesComplete += (int)this.NumberOfChannels;

            }

            lastOverallPosition += numSamplesComplete;

            return numSamplesComplete;

        }

        public void seek(long newPosition)
        {
            source.seek(newPosition / 3);

            // Reset input position
            lastInputBufferPosition = -1;

            lastOverallPosition = newPosition;

            currentState = States.Normal;

            // Reset overlap buffers
            Array.Clear(overlapLeftWoofer, 0, overlapLeftWoofer.Length);
            Array.Clear(overlapLeftMidrange, 0, overlapLeftMidrange.Length);
            Array.Clear(overlapLeftTweeter, 0, overlapLeftTweeter.Length);
            Array.Clear(overlapRightWoofer, 0, overlapRightWoofer.Length);
            Array.Clear(overlapRightMidrange, 0, overlapRightMidrange.Length);
            Array.Clear(overlapRightTweeter, 0, overlapRightTweeter.Length);
        }

        public long getOptimalReadSize()
        {
            return inputSegmentSize * source.NumberOfChannels;
        }

    }
}
