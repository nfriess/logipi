using System;
using System.Numerics;

using DeemphasisInternal;
using System.Diagnostics;

namespace AudioFilters
{
    /// <summary>
    /// Applies de-emphasis to the input, the inverse of an emphasis filter applied when
    /// an (older) recording was created.
    /// </summary>
    class DeemphasisFilter : IAudioFilter
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
        private Deemphasis deemphasis;
        private bool filterEnabled;
        private bool lastFilterEnabled;

        private States currentState;

        private int inputSegmentSize;

        private Complex[] H_kernel;
        private Complex[] H_identity; // Used when filterEnabled = false

        private Complex[] bufferLeft;
        private Complex[] bufferRight;

        private Complex[] overlapLeft;
        private Complex[] overlapRight;


        private long lastOverallPosition;
        private int lastInputBufferPosition;


        public DeemphasisFilter(IAudioFilter source, Deemphasis deemphasis, bool filterEnabled)
        {

            if (source.NumberOfChannels != 2)
                throw new ArgumentException("Audio source must have 2 channels", "source");

            if (source.SampleRate != deemphasis.sampleRate)
                throw new ArgumentException("Crossover sample rate does not match input source", "crossover");

            this.source = source;
            this.deemphasis = deemphasis;
            this.filterEnabled = filterEnabled;
            this.lastFilterEnabled = filterEnabled;

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
                return source.NumberOfChannels;
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
                return source.Length;
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

        private Complex[] createIdentityKernel(int fftSize)
        {
            Complex[] H = new Complex[fftSize];
            H[(int)Math.Floor((double)fftSize/2.0)] = new Complex(1.0, 0.0);
            FourierAnalysis.complexUnscaledFFT(H);
            return H;
        }

        /// <summary>
        /// Initializes all of the internal state based on the input crossover.
        /// </summary>
        private void initializeFilterKernels()
        {

            // Find the length of the filter kernels. We use the length of the woofer
            // kernel, but all 3 kernels should be exactly the sample length.
            int filterKernelLength = deemphasis.filterKernel.Length;

            // Calculate the size of the FFT. Take the length of the filter kernel
            // and double it, and then find the next power of 2. This will be the size
            // of the buffer that holds the zero-padded x/X/Y/y segments, and of
            // the H buffers.
            int fftSize = Utility.nextPowerOf2(filterKernelLength * 2);

            // Calculate the size of the input segment
            inputSegmentSize = fftSize - filterKernelLength + 1;

            // Calculate the size of the overlap
            int overlapSize = fftSize - inputSegmentSize;

            H_kernel = createUnscaledH(deemphasis.filterKernel, fftSize);
            H_identity = createIdentityKernel(fftSize);

            // Create the buffers that hold the six x/X/Y/y segments
            bufferLeft = new Complex[fftSize];
            bufferRight = new Complex[fftSize];

            // Create the buffers that hold the six overlap segments. These buffers
            // are initially filled with zeros.
            overlapLeft = new Complex[overlapSize];
            overlapRight = new Complex[overlapSize];

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
                Array.Copy(overlapLeft, 0, bufferLeft, 0, overlapLeft.Length);
                Array.Copy(overlapRight, 0, bufferRight, 0, overlapRight.Length);

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
                bufferLeft[i / 2] = sourceData[i];
                bufferRight[i / 2] = sourceData[i + 1];
            }

            framesRead /= 2;

            // Pad remaining part of these two buffers with zeros
            Array.Clear(bufferLeft, framesRead, bufferLeft.Length - framesRead);
            Array.Clear(bufferRight, framesRead, bufferRight.Length - framesRead);

            // Do an in-place unscaled FFT on the two buffers, giving us the
            // spectra X of the stereo input signals (i.e. X_left and X_right)
            FourierAnalysis.complexUnscaledFFT(bufferLeft);
            FourierAnalysis.complexUnscaledFFT(bufferRight);

            // Do the point-by-point complex multiply of H times X, which yields Y
            if (filterEnabled)
            {
                for (int i = 0; i < bufferLeft.Length; i++)
                {
                    bufferLeft[i] *= H_kernel[i];

                    bufferRight[i] *= H_kernel[i];
                }
            }
            else
            {
                for (int i = 0; i < bufferLeft.Length; i++)
                {
                    bufferLeft[i] *= H_identity[i];

                    bufferRight[i] *= H_identity[i];
                }
            }

            // Do an in-place scaled IFFT on the six buffers containing Y,
            // to yield 6 channels of y
            FourierAnalysis.complexScaledIFFT(bufferLeft);
            FourierAnalysis.complexScaledIFFT(bufferRight);

            // Don't use overlap old buffers if we switched kernels
            if (lastFilterEnabled == filterEnabled)
            {

                // Add the contents of the overlap buffers to the first part of the
                // y buffers
                for (int i = 0; i < overlapLeft.Length; i++)
                {
                    bufferLeft[i] += overlapLeft[i];
                    bufferRight[i] += overlapRight[i];
                }

            }
            else
            {
                lastFilterEnabled = filterEnabled;
            }

            Array.Copy(bufferLeft, inputSegmentSize, overlapLeft, 0, overlapLeft.Length);
            Array.Copy(bufferRight, inputSegmentSize, overlapRight, 0, overlapRight.Length);

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

                data[lastOffset++] = bufferLeft[lastInputBufferPosition].Real;
                data[lastOffset++] = bufferRight[lastInputBufferPosition].Real;

                lastInputBufferPosition++;

                numSamplesComplete += (int)this.NumberOfChannels;

            }

            lastOverallPosition += numSamplesComplete;

            return numSamplesComplete;

        }

        public void seek(long newPosition)
        {
            source.seek(newPosition);

            // Reset input position
            lastInputBufferPosition = -1;

            lastOverallPosition = newPosition;

            currentState = States.Normal;

            // Reset overlap buffers
            Array.Clear(overlapLeft, 0, overlapLeft.Length);
            Array.Clear(overlapRight, 0, overlapRight.Length);
        }

        public long getOptimalReadSize()
        {
            return inputSegmentSize * source.NumberOfChannels;
        }

        public void setEnabled(bool value)
        {
            this.filterEnabled = value;
        }

    }
}
