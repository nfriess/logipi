using System;

namespace DigitalCrossover
{
    class Crossover
    {

        public enum CROSSOVER_TYPES
        {
            TWO_WAY, THREE_WAY, FOUR_WAY
        }


        public CROSSOVER_TYPES crossoverType;
        public double crossoverFrequency1;
        public double crossoverFrequency2;
        public double crossoverFrequency3;
        public double transitionBandwidth1;
        public double transitionBandwidth2;
        public double transitionBandwidth3;
        public double sampleRate;
        public bool normalized;
        public double scalingFactor;
        public int outputSignalDelay;
        public bool doAnalysis;
        public double binSize;
        public double[] wooferFilterKernel;
        public double[] midrangeFilterKernel;
        public double[] upperMidFilterKernel;
        public double[] tweeterFilterKernel;
        public double[] summedFilterKernel;
        public FilterResponse wooferFilterResponse;
        public FilterResponse midrangeFilterResponse;
        public FilterResponse upperMidFilterResponse;
        public FilterResponse tweeterFilterResponse;
        public FilterResponse summedFilterResponse;

        private Crossover(CROSSOVER_TYPES crossoverType, double crossoverFrequency1, double crossoverFrequency2,
            double crossoverFrequency3, double transitionBandwidth1, double transitionBandwidth2,
            double transitionBandwidth3, double sampleRate, bool normalized, double scalingFactor,
            int outputSignalDelay, bool doAnalysis, double binSize)
        {
            this.crossoverType = crossoverType;
            this.crossoverFrequency1 = crossoverFrequency1;
            this.crossoverFrequency2 = crossoverFrequency2;
            this.crossoverFrequency3 = crossoverFrequency3;
            this.transitionBandwidth1 = transitionBandwidth1;
            this.transitionBandwidth2 = transitionBandwidth2;
            this.transitionBandwidth3 = transitionBandwidth3;
            this.sampleRate = sampleRate;
            this.normalized = normalized;
            this.scalingFactor = scalingFactor;
            this.outputSignalDelay = outputSignalDelay;
            this.doAnalysis = doAnalysis;
            this.binSize = binSize;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createTwoWayCrossover
        //
        //  Arguments:      crossoverFrequency:     Cutoff frequency of the lowpass
        //											filter and highpass filter,
        //											specified in Hertz. Must satisfy:
        //											0 < crossover <= sampleRate/2.
        //                  transitionBandwidth:    Width of the transition band in Hz.
        //											Must be: 0 < BW <= sampleRate/4.
        //                  sampleRate:     		System sample rate in Hertz. Must
        //											be greater than 0.
        //                  normalized:             If set to true, this function will
        //                                          adjust the filter kernels so that
        //                                          a small amount of headroom is added
        //                                          to avoid clipping.
        //                  doAnalysis:             If set to true, this function will
        //                                          calculate the filter responses, and
        //                                          create and analyze the summed
        //                                          filter kernel.
        //                  binSize:                The bin size width in Hz for each
        //                                          analysis bin when calculating the
        //                                          filter frequency response.
        //
        //  Returns:        Returns a pointer to a struct containing pointers to the
        //					two filter kernels.
        //
        //  Description:    This function creates two filter kernels for a two-way
        //					crossover system.  A lowpass filter is created for the
        //					woofer, and a highpass filter for the tweeter.  The two
        //					filters are complementary, since the tweeter filter is
        //					the spectral inversion of the woofer filter.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Crossover createTwoWayCrossover(double crossoverFrequency,
                                           double transitionBandwidth,
                                           double sampleRate, bool normalized,
                                           bool doAnalysis, double binSize)
        {
            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the transitionBandwidth is > 0 and <= sampleRate/4
            if ((transitionBandwidth <= 0) || (transitionBandwidth > sampleRate / 6))
                throw new ArgumentOutOfRangeException("transitionBandwidth", "" + transitionBandwidth);

            // Make sure the binsize is > 0 and <= 1/4 of the sample rate. This
            // guarantees at least 3 data points when calculating the filter
            // response, i.e. at DC, nyquist/2, and nyquist.
            if ((binSize <= 0) || (binSize > sampleRate / 4))
                throw new ArgumentOutOfRangeException("binSize", "" + binSize);

            // Make sure that f1 >= (transbw/2) and f2 <= (sampleRate/2 - transbw/2)
            if ((crossoverFrequency < transitionBandwidth / 2) ||
                   (crossoverFrequency > (sampleRate / 2) - (transitionBandwidth / 2)))
                throw new ArgumentException("crossoverFrequency with transition is too wide");

            // Store the initial filter design characteristics in the struct.
            // Note: some of these values will be changed later in this function.
            Crossover crossover = new Crossover(CROSSOVER_TYPES.TWO_WAY, crossoverFrequency, 0.0, 0.0,
                transitionBandwidth, 0.0, 0.0, sampleRate, normalized, 1.0, 0, doAnalysis, binSize);

            // Create the lowpass filter kernel for the woofer
            crossover.wooferFilterKernel = createLPFilter(crossoverFrequency,
                                                           transitionBandwidth,
                                                           sampleRate);

            // Create the highpass filter kernel for the tweeter:
            // Do a spectral inversion of the lowpass woofer filter kernel. Note that
            // the tweeter kernel will be the same length as the woofer kernel.
            crossover.tweeterFilterKernel =
                createSpectralInversion(crossover.wooferFilterKernel);

            // If requested, normalize the filter kernels so that any passband
            // ripple is limited to unity gain. This is now done by arbitrarily
            // scaling the filter kernels to add some headroom.
            if (normalized)
            {
                //limitRipple(crossover);
                addHeadroom(crossover);
            }

            // Calculate the output signal delay in signal in samples (note: assumes
            // integer division)
            crossover.outputSignalDelay = crossover.wooferFilterKernel.Length / 2;

            // If we are doing analysis, then create the summed filter kernel, and
            // calculate the filter response for each filter kernel
            if (doAnalysis)
            {
                // Sum the two filter kernels together to produce a
                // "summed filter kernel"
                crossover.summedFilterKernel = new double[crossover.wooferFilterKernel.Length];
                for (int i = 0; i < crossover.wooferFilterKernel.Length; i++)
                {
                    crossover.summedFilterKernel[i] = crossover.wooferFilterKernel[i] +
                        crossover.tweeterFilterKernel[i];
                }

                // Calculate the filter response for each filter kernel
                crossover.wooferFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.wooferFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.tweeterFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.tweeterFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.summedFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.summedFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
            }

            // Return a pointer to the newly created two-way crossover system
            return crossover;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createThreeWayCrossover
        //
        //  Arguments:      crossoverFrequency1:    First crossover frequency,
        //                                          specified in Hertz. Must satisfy:
        //                                          0 < crossover1 <= sampleRate/2.
        //					crossoverFrequency2:    Second crossover frequency,
        //                                          specified in Hertz. Must satisfy:
        //                                          0 < crossover2 <= sampleRate/2.
        //                                          Also: crossover1 < crossover2.
        //                  transitionBandwidth1:   Width of the 1st transition band in
        //                                          Hz. Must be: 0 < BW <= sampleRate/6.
        //                  transitionBandwidth2:   Width of the 2nd transition band in
        //                                          Hz. Must be: 0 < BW <= sampleRate/6.
        //                  sampleRate:     		System sample rate in Hertz. Must
        //                                          be greater than 0.
        //                  normalized:             If set to true, this function will
        //                                          adjust the filter kernels so that
        //                                          any passband ripple is no greater
        //                                          than unity gain.
        //                  doAnalysis:             If set to true, this function will
        //                                          calculate the filter responses, and
        //                                          create and analyze the summed
        //                                          filter kernel.
        //                  binSize:                The bin size width in Hz for each
        //                                          analysis bin when calculating the
        //                                          filter frequency response.
        //
        //  Returns:        Returns a pointer to a struct containing pointers to the
        //                  three filter kernels.
        //
        //  Description:    This function creates three filter kernels for a three-way
        //                  crossover system.  A lowpass filter is created for the
        //                  woofer, a highpass filter for the tweeter, and a bandpass
        //                  filter for the midrange speaker. The three filters are
        //                  complementary, since spectral inversion is used to create
        //                  them. In other words, summing the outputs of the three
        //                  filters should result in the same signal as the input
        //                  signal.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Crossover createThreeWayCrossover(double crossoverFrequency1,
                                             double crossoverFrequency2,
                                             double transitionBandwidth1,
                                             double transitionBandwidth2,
                                             double sampleRate, bool normalized,
                                             bool doAnalysis, double binSize)
        {
            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the transitionBandwidths are > 0 and <= sampleRate/6
            if ((transitionBandwidth1 <= 0) || (transitionBandwidth1 > sampleRate / 6))
                throw new ArgumentOutOfRangeException("transitionBandwidth1", "" + transitionBandwidth1);
            if ((transitionBandwidth2 <= 0) || (transitionBandwidth2 > sampleRate / 6))
                throw new ArgumentOutOfRangeException("transitionBandwidth2", "" + transitionBandwidth2);

            // Make sure the binsize is > 0 and <= 1/4 of the sample rate. This
            // guarantees at least 3 data points when calculating the filter
            // response, i.e. at DC, nyquist/2, and nyquist.
            if ((binSize <= 0) || (binSize > sampleRate / 4))
                throw new ArgumentOutOfRangeException("binSize", "" + binSize);

            // Make sure that f1 is not too low, taking into account
            // transition bandwidth 1
            if (crossoverFrequency1 < transitionBandwidth1 / 2)
                throw new ArgumentOutOfRangeException("crossoverFrequency1", "" + crossoverFrequency1);

            // Make sure that there is enough distance between f1 and f2
            if ((crossoverFrequency1 + transitionBandwidth1 / 2) >
                   (crossoverFrequency2 - transitionBandwidth2 / 2))
                throw new ArgumentException("crossoverFrequency1 and crossoverFrequency2 are too close");

            // Make sure that f2 is not too high, taking into account
            // transition bandwidth 2
            if (crossoverFrequency2 > (sampleRate / 2 - transitionBandwidth2 / 2))
                throw new ArgumentOutOfRangeException("crossoverFrequency2", "" + crossoverFrequency2);

            // Store the initial filter design characteristics in the struct.
            // Note: some of these values will be changed later in this function.
            Crossover crossover = new Crossover(CROSSOVER_TYPES.THREE_WAY,
                crossoverFrequency1, crossoverFrequency2, 0.0,
                transitionBandwidth1, transitionBandwidth2, 0.0,
                sampleRate, normalized, 1.0, 0, doAnalysis, binSize);

            // Create the lowpass filter kernel for the woofer
            crossover.wooferFilterKernel = createLPFilter(crossoverFrequency1,
                                                           transitionBandwidth1,
                                                           sampleRate);

            // Create the highpass filter kernel for the tweeter:
            // First create a lowpass filter kernel with a cutoff at
            // crossover frequency 2 and transition bandwidth 2
            double[] lpfilter = createLPFilter(crossoverFrequency2,
                                                    transitionBandwidth2,
                                                    sampleRate);

            // Do a spectral inversion of the lowpass filter, to create the highpass
            // filter for the tweeter
            crossover.tweeterFilterKernel = createSpectralInversion(lpfilter);

            // If the transition bandwidths are not equal, then the two filter kernels
            // will be of different length, and we will have to pad one of them with
            // zeros at the beginning and end
            if (crossover.wooferFilterKernel.Length >
                crossover.tweeterFilterKernel.Length)
            {
                // Calculate how many zeros to pad at the beginning
                int padding = (crossover.wooferFilterKernel.Length -
                               crossover.tweeterFilterKernel.Length) / 2;

                // Create the new, larger vector to hold the filter kernel
                double[] temp = new double[crossover.wooferFilterKernel.Length];

                // Center the tweeter filter kernel in the larger vector. Note that
                // the real vector is initialized with zeros when created.
                for (int i = padding, j = 0; j < crossover.tweeterFilterKernel.Length;
                     i++, j++)
                {
                    temp[i] = crossover.tweeterFilterKernel[j];
                }

                // Set the pointer to the new (longer) tweeter filter kernel
                crossover.tweeterFilterKernel = temp;
            }
            else if (crossover.tweeterFilterKernel.Length >
                     crossover.wooferFilterKernel.Length)
            {
                // Calculate how many zeros to pad at the beginning
                int padding = (crossover.tweeterFilterKernel.Length -
                               crossover.wooferFilterKernel.Length) / 2;

                // Create the new, larger vector to hold the filter kernel
                double[] temp = new double[crossover.tweeterFilterKernel.Length];

                // Center the woofer filter kernel in the larger vector. Note that
                // the real vector is initialized with zeros when created.
                for (int i = padding, j = 0; j < crossover.wooferFilterKernel.Length;
                     i++, j++)
                {
                    temp[i] = crossover.wooferFilterKernel[j];
                }

                // Set the pointer to the new (longer) woofer filter kernel
                crossover.wooferFilterKernel = temp;
            }

            // Create the bandpass filter kernel for the midrange:
            // First create a notch filter (band-reject filter) with cutoffs at
            // crossover frequencies 1 and 2.  This is done by adding the impulse
            // responses (filter kernels) of the woofer and tweeter filters.
            double[] notchfilter = new double[crossover.wooferFilterKernel.Length];
            for (int i = 0; i < crossover.wooferFilterKernel.Length; i++)
            {
                notchfilter[i] = crossover.wooferFilterKernel[i] + crossover.tweeterFilterKernel[i];
            }

            // Do a spectral inversion of the notch filter, to create a bandpass
            // filter for the midrange
            crossover.midrangeFilterKernel = createSpectralInversion(notchfilter);

            // If requested, normalize the filter kernels so that any passband
            // ripple limited to unity gain. This is now done by arbitrarily
            // scaling to filter kernels to add some headroom.
            if (normalized)
            {
                //limitRipple(crossover);
                addHeadroom(crossover);
            }

            // Calculate the output signal delay in signal in samples (note: assumes
            // integer division)
            crossover.outputSignalDelay = crossover.wooferFilterKernel.Length / 2;

            // If we are doing analysis, then create the summed filter kernel, and
            // calculate the filter response for each filter kernel
            if (doAnalysis)
            {
                // Sum the three filter kernels together to produce a
                // "summed filter kernel"
                crossover.summedFilterKernel = new double[crossover.wooferFilterKernel.Length];
                for (int i = 0; i < crossover.wooferFilterKernel.Length; i++)
                {
                    crossover.summedFilterKernel[i] = crossover.wooferFilterKernel[i] +
                        crossover.midrangeFilterKernel[i] + crossover.tweeterFilterKernel[i];
                }

                // Calculate the filter response for each filter kernel
                crossover.wooferFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.wooferFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.midrangeFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.midrangeFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.tweeterFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.tweeterFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.summedFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.summedFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
            }

            // Return a pointer to the newly created three-way crossover system
            return crossover;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createFourWayCrossover
        //
        //  Arguments:      crossoverFrequency1:    First crossover frequency,
        //											specified in Hertz. Must satisfy:
        //											0 < crossover1 <= sampleRate/2.
        //					crossoverFrequency2:    Second crossover frequency,
        //											specified in Hertz. Must satisfy:
        //											0 < crossover2 <= sampleRate/2.
        //                  crossoverFrequency3:    Third crossover frequency,
        //											specified in Hertz. Must satisfy:
        //											0 < crossover3 <= sampleRate/2.
        //											Also: crossover1 < crossover2 and
        //                                          crossover2 < crossover3.
        //                  transitionBandwidth1:   Width of the 1st transition band in
        //											Hz. Must be: 0 < BW <= sampleRate/8.
        //                  transitionBandwidth2:   Width of the 2nd transition band in
        //											Hz. Must be: 0 < BW <= sampleRate/8.
        //                  transitionBandwidth3:   Width of the 3rd transition band in
        //											Hz. Must be: 0 < BW <= sampleRate/8.
        //                  sampleRate:     		System sample rate in Hertz. Must
        //											be greater than 0.
        //                  normalized:             If set to true, this function will
        //                                          adjust the filter kernels so that
        //                                          a small amount of headroom is added
        //                                          to avoid clipping.
        //                  doAnalysis:             If set to true, this function will
        //                                          calculate the filter responses, and
        //                                          create and analyze the summed
        //                                          filter kernel.
        //                  binSize:                The bin size width in Hz for each
        //                                          analysis bin when calculating the
        //                                          filter frequency response.
        //
        //  Returns:        Returns a pointer to a struct containing pointers to the
        //					four filter kernels.
        //
        //  Description:    This function creates four filter kernels for a four-way
        //					crossover system.  A lowpass filter is created for the
        //					woofer, a highpass filter for the tweeter, and bandpass
        //                  filters for the midrange and upper mid speakers. The four
        //                  filters are complementary, since spectral inversion is used
        //                  to create them. In other words, summing the outputs of the
        //                  four filters should result in the same signal as the input
        //					signal.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Crossover createFourWayCrossover(double crossoverFrequency1,
                                            double crossoverFrequency2,
                                            double crossoverFrequency3,
                                            double transitionBandwidth1,
                                            double transitionBandwidth2,
                                            double transitionBandwidth3,
                                            double sampleRate, bool normalized,
                                            bool doAnalysis, double binSize)
        {
            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the transitionBandwidths are > 0 and <= sampleRate/8
            if ((transitionBandwidth1 <= 0) || (transitionBandwidth1 > sampleRate / 8))
                throw new ArgumentOutOfRangeException("transitionBandwidth1", "" + transitionBandwidth1);
            if ((transitionBandwidth2 <= 0) || (transitionBandwidth2 > sampleRate / 8))
                throw new ArgumentOutOfRangeException("transitionBandwidth2", "" + transitionBandwidth2);
            if ((transitionBandwidth3 <= 0) || (transitionBandwidth3 > sampleRate / 8))
                throw new ArgumentOutOfRangeException("transitionBandwidth3", "" + transitionBandwidth3);

            // Make sure the binsize is > 0 and <= 1/4 of the sample rate. This
            // guarantees at least 3 data points when calculating the filter
            // response, i.e. at DC, nyquist/2, and nyquist.
            if ((binSize <= 0) || (binSize > sampleRate / 4))
                throw new ArgumentOutOfRangeException("binSize", "" + binSize);

            // Make sure that f1 is not too low, taking into account
            // transition bandwidth 1
            if (crossoverFrequency1 < transitionBandwidth1 / 2)
                throw new ArgumentOutOfRangeException("crossoverFrequency1", "" + crossoverFrequency1);

            // Make sure that there is enough distance between f1 and f2
            if ((crossoverFrequency1 + transitionBandwidth1 / 2) >
                   (crossoverFrequency2 - transitionBandwidth2 / 2))
                throw new ArgumentException("crossoverFrequency1 and crossoverFrequency2 are too close");

            // Make sure that there is enough distance between f2 and f3
            if ((crossoverFrequency2 + transitionBandwidth2 / 2) >
                   (crossoverFrequency3 - transitionBandwidth3 / 2))
                throw new ArgumentException("crossoverFrequency2 and transitionBandwidth3 are too close");

            // Make sure that f3 is not too high, taking into account
            // transition bandwidth 3
            if (crossoverFrequency3 > (sampleRate / 2 - transitionBandwidth3 / 2))
                throw new ArgumentOutOfRangeException("crossoverFrequency1", "" + crossoverFrequency1);

            // Store the initial filter design characteristics in the struct.
            // Note: some of these values will be changed later in this function.
            Crossover crossover = new Crossover(CROSSOVER_TYPES.FOUR_WAY,
                crossoverFrequency1, crossoverFrequency2, crossoverFrequency3,
                transitionBandwidth1, transitionBandwidth2, transitionBandwidth3,
                sampleRate, normalized, 1.0, 0, doAnalysis, binSize);

            // Create the lowpass filter kernel for the woofer at f1
            crossover.wooferFilterKernel = createLPFilter(crossoverFrequency1,
                                                           transitionBandwidth1,
                                                           sampleRate);

            // Create a temporary highpass filter kernel at f2
            double[] tempHPFilter = createHPFilter(crossoverFrequency2,
                                                        transitionBandwidth2,
                                                        sampleRate);

            // If the transition bandwidths are not equal, then the two filter kernels
            // will be of different length. In this case, we will have to pad one of
            // them with zeros at the beginning and end to equalize their lengths.
            equalizeKernelLengths(ref crossover.wooferFilterKernel,
                                  ref tempHPFilter);

            // Create the bandpass filter kernel for the midrange, using the woofer LP
            // and temporary HP filter kernels
            crossover.midrangeFilterKernel =
                createBPFilter(crossover.wooferFilterKernel, tempHPFilter);

            // Create the highpass filter kernel for the tweeter at f3
            crossover.tweeterFilterKernel =
                createHPFilter(crossoverFrequency3, transitionBandwidth3, sampleRate);

            // Create a temporary lowpass filter kernel at f2
            double[] tempLPFilter =
                createLPFilter(crossoverFrequency2, transitionBandwidth2, sampleRate);

            // If the transition bandwidths are not equal, then the two filter kernels
            // will be of different length. In this case, we will have to pad one of
            // them with zeros at the beginning and end to equalize their lengths.
            equalizeKernelLengths(ref tempLPFilter, ref crossover.tweeterFilterKernel);

            // Create the bandpass filter kernel for the upper mid, using the temporary
            // LP filter and tweeter filter kernels
            crossover.upperMidFilterKernel =
                createBPFilter(tempLPFilter, crossover.tweeterFilterKernel);

            // Adjust the kernel lengths so that they are all the same length
            // as the longest filter kernel
            adjustKernelLengths(crossover);

            // If requested, normalize the filter kernels so that any passband
            // ripple is limited to unity gain. This is now done by arbitrarily
            // scaling the filter kernels to add some headroom.
            if (normalized)
            {
                //limitRipple(crossover);
                addHeadroom(crossover);
            }

            // Calculate the output signal delay in signal in samples (note: assumes
            // integer division)
            crossover.outputSignalDelay = crossover.wooferFilterKernel.Length / 2;

            // If we are doing analysis, then create the summed filter kernel, and
            // calculate the filter response for each filter kernel
            if (doAnalysis)
            {
                // Sum the four filter kernels together to produce a
                // "summed filter kernel"
                crossover.summedFilterKernel = new double[crossover.wooferFilterKernel.Length];
                for (int i = 0; i < crossover.wooferFilterKernel.Length; i++)
                {
                    crossover.summedFilterKernel[i] = crossover.wooferFilterKernel[i] +
                        crossover.midrangeFilterKernel[i] + crossover.upperMidFilterKernel[i] +
                        crossover.tweeterFilterKernel[i];
                }

                // Calculate the filter response for each filter kernel
                crossover.wooferFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.wooferFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.midrangeFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.midrangeFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.upperMidFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.upperMidFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.tweeterFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.tweeterFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
                crossover.summedFilterResponse =
                    FilterResponse.calculateFilterResponse(crossover.summedFilterKernel,
                                            crossover.sampleRate,
                                            crossover.binSize);
            }

            // Return a pointer to the newly created four-way crossover system
            return crossover;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       padKernel
        //
        //  Arguments:      kernel:        Reference to the kernel pointer.
        //                  newLength:     The new, larger length for the kernel.
        //
        //  Returns:        void
        //
        //  Description:    This function pads an existing kernel with zeroes to a new
        //                  (larger) length, centering the kernel in a newly-allocated
        //                  vector as it does so. This vector replaces the old (shorter)
        //                  kernel, which is deallocated in memory.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void padKernel(ref double[] kernel, int newLength)
        {
            // Make sure we have a valid pointer argument
            if (kernel == null)
                throw new ArgumentNullException("kernel");

            // Find the length of the kernel
            int kernelLength = kernel.Length;

            // Make sure the new length argument is larger than the size of the kernel
            // by at least 2 elements
            if (newLength < (kernelLength + 2))
                throw new ArgumentException("newLength must be at least 2 elements greater than kernel.Length", "newLength");

            // Make sure the new length is an odd integer
            if ((newLength % 2) != 1)
                throw new ArgumentException("newLength must be an odd integer", "newLength");

            // Calculate how many zeros to pad at the beginning (and end)
            int padding = (newLength - kernelLength) / 2;

            // Create the new, larger vector to hold the filter kernel
            double[] temp = new double[newLength];

            // Center the filter kernel in the larger vector. Note that
            // the real vector is initialized with zeros when created.
            Array.Copy(kernel, 0, temp, padding, kernelLength);

            // Set the pointer to the new (longer) filter kernel
            kernel = temp;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       equalizeKernelLengths
        //
        //  Arguments:      kernel1:     Reference to the first kernel pointer.
        //                  kernel2:     Reference to the second kernel pointer.
        //
        //  Returns:        void
        //
        //  Description:    This function compares the length of two filter kernels,
        //                  and if they are different, it copies the shorter kernel
        //                  into a newly-created vector of the longer length, centering
        //                  the kernel as it does so. Zero padding is done at the
        //                  beginning and end. This function is used when the
        //                  transition bandwidths are different for the two filter
        //                  kernels and they need to be combined in some way (usually
        //                  to create a notch or bandpass filter).
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void equalizeKernelLengths(ref double[] kernel1, ref double[] kernel2)
        {
            // Make sure we have valid argment pointers
            if (kernel1 == null)
                throw new ArgumentNullException("kernel1");
            if (kernel2 == null)
                throw new ArgumentNullException("kernel2");

            // Find the length of kernels 1 and 2
            int length1 = kernel1.Length;
            int length2 = kernel2.Length;

            // Increase the size of a kernel to be the same as the other
            if (length2 < length1)
            {
                // Pad out the second kernel if it is shorter than the first
                padKernel(ref kernel2, length1);
            }
            else if (length1 < length2)
            {
                // Pad out the first kernel if it is shorter than the second
                padKernel(ref kernel1, length2);
            }
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       adjustKernelLengths
        //
        //  Arguments:      crossover:     A pointer to the crossover struct.
        //
        //  Returns:        void
        //
        //  Description:    This function equalizes the lengths of the 4 filter kernels
        //                  so that they are the same length as the longest filter
        //                  kernel. It does so by creating a new (longer) vector,
        //                  copying the old kernel into the middle of the vector, and
        //                  padding with zeroes at the beginning and end. This function
        //                  should only be called when creating a four-way crossover.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void adjustKernelLengths(Crossover crossover)
        {
            // TOOD: Fixed ordering of asserts

            // Make sure we have valid pointer arguments
            if (crossover == null)
                throw new ArgumentNullException("crossover");
            if (crossover.wooferFilterKernel == null)
                throw new ArgumentNullException("crossover.wooferFilterKernel");
            if (crossover.midrangeFilterKernel == null)
                throw new ArgumentNullException("crossover.midrangeFilterKernel");
            if (crossover.upperMidFilterKernel == null)
                throw new ArgumentNullException("crossover.upperMidFilterKernel");
            if (crossover.tweeterFilterKernel == null)
                throw new ArgumentNullException("crossover.tweeterFilterKernel");

            // Make sure we are adjusting a four-way crossover
            if (crossover.crossoverType != CROSSOVER_TYPES.FOUR_WAY)
                throw new ArgumentException("crossoverType must be FOUR_WAY", "crossover.crossoverType");

            // First find the longest kernel length
            int maxLength = 0;
            maxLength = crossover.wooferFilterKernel.Length > maxLength ?
                        crossover.wooferFilterKernel.Length : maxLength;
            maxLength = crossover.midrangeFilterKernel.Length > maxLength ?
                        crossover.midrangeFilterKernel.Length : maxLength;
            maxLength = crossover.upperMidFilterKernel.Length > maxLength ?
                        crossover.upperMidFilterKernel.Length : maxLength;
            maxLength = crossover.tweeterFilterKernel.Length > maxLength ?
                        crossover.tweeterFilterKernel.Length : maxLength;

            // Adjust the length of each kernel in turn, as necessary
            if (crossover.wooferFilterKernel.Length < maxLength)
            {
                padKernel(ref crossover.wooferFilterKernel, maxLength);
            }
            if (crossover.midrangeFilterKernel.Length < maxLength)
            {
                padKernel(ref crossover.midrangeFilterKernel, maxLength);
            }
            if (crossover.upperMidFilterKernel.Length < maxLength)
            {
                padKernel(ref crossover.upperMidFilterKernel, maxLength);
            }
            if (crossover.tweeterFilterKernel.Length < maxLength)
            {
                padKernel(ref crossover.tweeterFilterKernel, maxLength);
            }
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createBPFilter
        //
        //  Arguments:      lpfilter:     A pointer to a lowpass filter kernel.
        //                  hpfilter:     A pointer to a highpass filter kernel.
        //
        //  Returns:        A pointer to the vector containing the bandpass filter
        //                  kernel.
        //
        //  Description:    This function creates and returns the filter kernel for a
        //                  a bandpass filter. First, a notch (band-reject) filter is
        //                  created using the specified lowpass and highpass filter
        //                  kernels. The bandpass filter kernel is then created by
        //                  doing spectral inversion of the notch filter. The lp and hp
        //                  filters must be exactly the same length.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] createBPFilter(double[] lpfilter, double[] hpfilter)
        {
            // Make sure we have valid pointer arguments
            if (lpfilter == null)
                throw new ArgumentNullException("lpfilter");
            if (hpfilter == null)
                throw new ArgumentNullException("hpfilter");

            // Make sure the filter kernels are the same length
            if (lpfilter.Length != hpfilter.Length)
                throw new ArgumentException("lpfilter and hpfilter must be of the same length", "lpfilter.Length");

            // First create a notch filter:  This is done by adding the impulse
            // responses (filter kernels) of the lowpass and highpass filters.
            double[] notchfilter = new double[lpfilter.Length];
            for (int i = 0; i < lpfilter.Length; i++)
            {
                notchfilter[i] = lpfilter[i] + hpfilter[i];
            }

            // Do a spectral inversion of the notch filter, to create a bandpass filter
            double[] bpfilter = createSpectralInversion(notchfilter);

            // Return a pointer to the bandpass filter kernel
            return bpfilter;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createHPFilter
        //
        //  Arguments:      cutoffFrequency:     	Cutoff frequency of the highpass
        //											filter, specified in Hertz. Must be
        //											0 < cutoff <= sampleRate/2.
        //                  transitionBandwidth:    Width of the transition band in Hz.
        //											Must be 0 < BW <= sampleRate/2.
        //                  sampleRate:     		System sample rate in Hertz. Must
        //											be greater than 0.
        //
        //  Returns:        A pointer to the vector containing the high pass filter
        //                  kernel.
        //
        //  Description:    This function creates and returns the filter kernel
        //                  for a highpass filter with the specified cutoff frequency
        //                  and bandwidth.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] createHPFilter(double cutoffFrequency, double transitionBandwidth,
                                     double sampleRate)
        {
            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the cutoff frequency is greater than 0
            // and less than one-half the sample rate
            if ((cutoffFrequency <= 0) || (cutoffFrequency > sampleRate / 2))
                throw new ArgumentOutOfRangeException("cutoffFrequency", "" + cutoffFrequency);

            // Make sure the transitionBandwidth is greater than 0
            // and less than one-half of the sample rate
            if ((transitionBandwidth <= 0) || (transitionBandwidth > sampleRate / 2))
                throw new ArgumentOutOfRangeException("transitionBandwidth", "" + transitionBandwidth);

            // First create a lowpass filter kernel with the specified
            // cutoff frequency and transition bandwidth
            double[] lpfilter = createLPFilter(cutoffFrequency,
                                                    transitionBandwidth,
                                                    sampleRate);

            // Do a spectral inversion of the lowpass filter, to create the
            // highpass filter
            double[] hpfilter = createSpectralInversion(lpfilter);

            // Return the newly created highpass filter kernel
            return hpfilter;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createLPFilter
        //
        //  Arguments:      cutoffFrequency:     	Cutoff frequency of the lowpass
        //                                          filter, specified in Hertz. Must be
        //                                          0 < cutoff <= sampleRate/2.
        //                  transitionBandwidth:    Width of the transition band in Hz.
        //                                          Must be 0 < BW <= sampleRate/2.
        //                  sampleRate:     		System sample rate in Hertz. Must
        //                                          be greater than 0.
        //
        //  Returns:        A pointer to the vector containing the filter kernel.
        //
        //  Description:    Creates and returns the filter kernel for a lowpass filter.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] createLPFilter(double cutoffFrequency, double transitionBandwidth,
                                      double sampleRate)
        {
            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the cutoff frequency is greater than 0
            // and less than one-half the sample rate
            if ((cutoffFrequency <= 0) || (cutoffFrequency > sampleRate / 2))
                throw new ArgumentOutOfRangeException("cutoffFrequency", "" + cutoffFrequency);

            // Make sure the transitionBandwidth is greater than 0
            // and less than one-half of the sample rate
            if ((transitionBandwidth <= 0) || (transitionBandwidth > sampleRate / 2))
                throw new ArgumentOutOfRangeException("transitionBandwidth", "" + transitionBandwidth);

            // Calculate the length of the filter kernel
            double fractionalTransitionBW = transitionBandwidth / sampleRate;
            uint filterLength = (uint)Math.Round(4 / fractionalTransitionBW);

            // Adjust the filter length, to make sure it is an odd integer
            if ((filterLength % 2) == 0)
                filterLength += 1;

            // Allocate a real vector of the appropriate length
            double[] vector = new double[filterLength];

            // Create a Sinc function in the vector
            createSinc(vector, cutoffFrequency, sampleRate);

            /*for (int i = 0; i < vector.Length; i++)
            {
                byte[] b = BitConverter.GetBytes(vector[i]);
                Console.WriteLine("" + i + " " + b[0] + " " + b[1] + " " + b[2] + " " + b[3] + " " + b[4] + " " + b[5] + " " + b[6] + " " + b[7]);
            }*/

            // Apply the Blackman-Harris window to the sinc function. This
            // window seems to give the best results, with very good stopband
            // rejection, limited passband and stopband ripple, and damped pre-
            // and post-ringing towards the outer edges of the window
            applyHarrisWindow(vector);

            // One could apply a Blackman or Kaiser window to the sinc function
            // instead of the Blackman-Harris window. If this is desired, comment
            // out the function call above, and uncomment one of the following lines:
            // applyBlackmanWindow(vector);
            // applyKaiserWindow(vector, 11.0L);

            // Normalize the filter kernel so that it has unity gain at 0 Hz
            normalize(vector);

            // Return the filter kernel as a vector of real numbers
            return vector;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createSpectralInversion
        //
        //  Arguments:      sourceKernel:	A vector containing the source filter
        //                                  kernel.
        //
        //  Returns:        A pointer to the vector containing the new filter kernel.
        //
        //  Description:    This function creates and returns a new filter kernel which
        //                  is the spectral inversion of the source filter kernel.  The
        //                  new filter will have the same cutoff frequency and
        //                  transition bandwidth, but the frequency domain spectrum
        //                  will be its exact inverse.  Commonly, one passes in the
        //                  kernel for a lowpass filter, and returns the kernel for
        //                  the complementary highpass filter.  Spectral inversion is
        //                  described on p. 272 of Smith's "Digital Signal Processing".
        //                  Essentially, we calculate the new kernel with:
        //                      delta[n] - h[n]
        //                  where delta[n] a single 1.0 value at the midpoint (and
        //                  0.0 everywhere else), and h[n] is the source filter's
        //                  impulse response.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static double[] createSpectralInversion(double[] sourceKernel)
        {
            // Make sure the pointer argument is not null
            if (sourceKernel == null)
                throw new ArgumentNullException("sourceKernel");

            // Make sure the size of the sourceKernel is an odd positive integer
            if ((sourceKernel.Length < 1) || ((sourceKernel.Length % 2) != 1))
                throw new ArgumentException("size of the sourceKernel must be an odd positive integer", "sourceKernel.Length");

            // Allocate a vector for the new kernel
            double[] newKernel = new double[sourceKernel.Length];

            // Read from source kernel, multiply each value by -1.0, and copy
            // the result into the new kernel
            for (int i = 0; i < sourceKernel.Length; i++)
                newKernel[i] = (double) - 1.0* sourceKernel[i];

            // Calculate the index of the midpoint of the array
            int midpoint = (newKernel.Length - 1) / 2;

            // Add 1.0 to the middle sample of the kernel
            newKernel[midpoint] += (double)1.0;

            // Return a pointer to the new filter kernel
            return newKernel;
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createSinc
        //
        //  Arguments:      vector:           The vector of reals that will receive
        //                                    the sinc function.
        //                  cutoffFrequency:  Cutoff frequency of the resulting
        //                                    lowpass filter, specified in Hertz.
        //                                    Must satisfy: 0 < cutoff <= sampleRate/2
        //                  sampleRate:       System sample rate in Hertz.
        //
        //  Returns:        void
        //
        //  Description:    Creates a sinc function in a vector of reals. The length of
        //                  the vector must be a positive odd integer.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void createSinc(double[] vector, double cutoffFrequency, double sampleRate)
        {
            // Make sure the pointer argument is not null
            if (vector == null)
                throw new ArgumentNullException("vector");

            // Make sure the size of the vector is an odd positive integer
            if ((vector.Length < 1) || ((vector.Length % 2) != 1))
                throw new ArgumentException("size of the vector must be an odd positive integer", "vector.Length");

            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the cutoff frequency is greater than 0
            // and less than one-half the sample rate
            if ((cutoffFrequency <= 0) || (cutoffFrequency > sampleRate / 2))
                throw new ArgumentOutOfRangeException("cutoffFrequency", "" + cutoffFrequency);

            // Calculate the fractional frequency
            double fractionalFrequency = cutoffFrequency / sampleRate;

            // Calculate omega
            double omega = Constants.TAU * fractionalFrequency;

            // Calculate the index of the midpoint of the array
            int midpoint = (vector.Length - 1) / 2;

            // Calculate the sinc function
            // The midpoint is calculated separately
            vector[midpoint] = omega;

            //Console.WriteLine(String.Format("omega = {0:F16}", omega));

            // Calculate the rest of the sinc function
            for (int i = midpoint - 1, j = midpoint + 1; i >= 0; i--, j++)
            {
                int dist = i - (int)midpoint;
                double theta = omega * dist;
                double sin_result = Math.Sin(theta);
                //Console.WriteLine(String.Format("{0:d} {1:d} sin({2:F16}) = {3:F16}", i, dist, theta, sin_result));
                byte[] b = BitConverter.GetBytes(sin_result);
                //Console.WriteLine(" " + b[0] + " " + b[1] + " " + b[2] + " " + b[3] + " " + b[4] + " " + b[5] + " " + b[6] + " " + b[7]);
                vector[i] = vector[j] = sin_result / dist;
            }

        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       applyHarrisWindow
        //
        //  Arguments:      vector:     Vector containing the signal. Vector length
        //                              should be a positive odd integer.
        //
        //  Returns:        void
        //
        //  Description:    Applies the minimum 4-term Blackman-Harris window to the
        //                  signal in the vector of reals. Using the specified
        //                  coefficients, this window produces a sidelobe that is
        //                  -92 dB down from the main lobe, with a -6 dB rolloff in
        //                  subsequent sidelobes.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void applyHarrisWindow(double[] vector)
        {
            // Make sure the pointer argument is not null
            if (vector == null)
                throw new ArgumentNullException("vector");

            // Make sure the size of the array is an odd positive integer
            if ((vector.Length < 1) || ((vector.Length % 2) != 1))
                throw new ArgumentException("size of the vector must be an odd positive integer", "vector.Length");

            // Apply the window to the signal
            for (int i = 0; i < vector.Length; i++)
            {
                vector[i] *= (double)0.35875 -
                    (double)0.48829 * Math.Cos((Constants.TAU * i) / (vector.Length - 1)) +
                    (double)0.14128 * Math.Cos((2 * Constants.TAU * i) / (vector.Length - 1)) -
                    (double)0.01168 * Math.Cos((3 * Constants.TAU * i) / (vector.Length - 1));
            }
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       normalize
        //
        //  Arguments:      vector:     Vector containing the signal.
        //
        //  Returns:        void
        //
        //  Description:    Normalizes the filter kernel for unity gain at 0 Hz.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void normalize(double[] vector)
        {
            double sum = 0.0;

            // Make sure the pointer argument is not null
            if (vector == null)
                throw new ArgumentNullException("vector");

            // Calculate the running sum of all sample values in the array
            for (int i = 0; i < vector.Length; i++)
                sum += vector[i];

            // Scale each sample, but only if the sum is greater than 0
            if (sum > 0.0)
            {
                for (int i = 0; i < vector.Length; i++)
                    vector[i] /= sum;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       addHeadroom
        //
        //  Arguments:      crossover:     The crossover system that contains
        //                                 filter kernels to be normalized.
        //
        //  Returns:        void
        //
        //  Description:    This function scales the filter kernels by an arbitrary
        //                  factor, so that any convolution done with the kernels
        //                  will not yield any signal clipping. The factor 0.94 seems
        //                  to work with extreme signals like a full-range sine tone
        //                  without any envelope (tested empirically).
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static void addHeadroom(Crossover crossover)
        {
            // Make sure we have a valid pointer to a crossover struct
            if (crossover == null)
                throw new ArgumentNullException("crossover");

            // Make sure we have valid pointers to the crossover's filter kernels
            if (crossover.wooferFilterKernel == null)
                throw new ArgumentNullException("crossover.wooferFilterKernel");
            if (crossover.crossoverType == CROSSOVER_TYPES.THREE_WAY)
            {
                if (crossover.midrangeFilterKernel == null)
                    throw new ArgumentNullException("crossover.midrangeFilterKernel");
            }
            if (crossover.crossoverType == CROSSOVER_TYPES.FOUR_WAY)
            {
                if (crossover.upperMidFilterKernel == null)
                    throw new ArgumentNullException("crossover.upperMidFilterKernel");
            }
            if (crossover.tweeterFilterKernel == null)
                throw new ArgumentNullException("crossover.tweeterFilterKernel");

            // Set the scaling Factor to the empirically-determined value
            crossover.scalingFactor = 0.94;

            // Scale the woofer, midrange (if a three-way or four-way crossover),
            // upper mid (if a four-way crossover), and tweeter filter kernels by
            // the scaling factor
            scaleRealVector(crossover.wooferFilterKernel, crossover.scalingFactor);
            if (crossover.crossoverType == CROSSOVER_TYPES.THREE_WAY || crossover.crossoverType == CROSSOVER_TYPES.FOUR_WAY)
            {
                scaleRealVector(crossover.midrangeFilterKernel, crossover.scalingFactor);
            }
            if (crossover.crossoverType == CROSSOVER_TYPES.FOUR_WAY)
            {
                scaleRealVector(crossover.upperMidFilterKernel, crossover.scalingFactor);
            }
            scaleRealVector(crossover.tweeterFilterKernel, crossover.scalingFactor);
        }

        private static void scaleRealVector(double[] vector, double scale)
        {
            for (int i = 0; i < vector.Length; i++)
                vector[i] *= scale;
        }

    }
}
