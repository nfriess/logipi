using System;
using System.Numerics;

namespace DeemphasisInternal
{
    class FilterResponse
    {
        double sampleRate;
        double binSize;
        uint numberDataPoints;
        double[] frequency;
        double[] amplitudeLinear;
        double[] amplitudeDB;
        double[] phaseRadians;
        double[] unwrappedPhase;
        double[] phaseDelay;
        double[] groupDelay;

        private FilterResponse(double sampleRate, double binSize)
        {
            this.sampleRate = sampleRate;
            this.binSize = binSize;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateFilterResponse
        //
        //  Arguments:      filterKernel:         A pointer to a real vector which
        //                                        contains the FIR filter coefficients.
        //                  sampleRate:           The sample rate used by the system,
        //                                        in samples per second.
        //                  binSize:              The frequency width of each analysis
        //                                        bin.
        //
        //  Returns:        A pointer to a newly allocated filterResponse struct, which
        //                  contains the calculated amplitude and phase response of the
        //                  filter kernel.
        //
        //  Description:    This function calculates the amplitude (both in linear and
        //                  dB scales) and phase (in radians) response of the inputted
        //                  filter kernel. The client must specify the sample rate and
        //                  the bin size. Note that the rst data point will be for 0 Hz,
        //                  and the last will be for the nyquist frequency. The actual
        //                  frequencies for each data point are contained in the
        //                  frequency vector.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static FilterResponse calculateFilterResponse(double[] filterKernel,
                                                  double sampleRate, double binSize)
        {
            // Make sure filterKernel is a valid pointer
            if (filterKernel == null)
                throw new ArgumentNullException("filterKernel");

            // Make sure the filter kernel length is at least one
            if (filterKernel.Length < 1)
                throw new ArgumentOutOfRangeException("filterKernel.Length", "" + filterKernel.Length);

            // Make sure the sample rate is greater than 0 Hz
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Make sure the bin size is greater than 0 Hz and less than
            // or equal to 1/4 the sample rate
            if ((binSize <= 0.0) || (binSize > sampleRate / 4.0))
                throw new ArgumentOutOfRangeException("binSize", "" + binSize);


            // Allocate memory for the filter response struct
            FilterResponse filterResponse = new FilterResponse(sampleRate, binSize);

            // Calculate the nyquist frequency
            double nyquist = 0.5 * sampleRate;

            // Calculate the number of data points to calculate. The bins size is the
            // gap in Hz between each data point. Remember that the frequency ranges
            // from 0 Hz (DC) to nyquist (1/2 the sample rate).
            filterResponse.numberDataPoints = (uint)Math.Round(nyquist / binSize) + 1;

            // Make sure the number of data points to calculate is 3 or greater
            if (filterResponse.numberDataPoints < 3)
                throw new ArgumentOutOfRangeException("filterResponse.numberDataPoints", "" + filterResponse.numberDataPoints);

            // Allocate the real vectors for the amplitude (linear scale) and
            // phase (in radians) responses
            filterResponse.frequency = new double[filterResponse.numberDataPoints];
            filterResponse.amplitudeLinear = new double[filterResponse.numberDataPoints];
            filterResponse.phaseRadians = new double[filterResponse.numberDataPoints];

            // Calculate loop constant
            Complex loopConstant = (Constants.PI / (filterResponse.numberDataPoints - 1)) * -Complex.ImaginaryOne;

            // Outer loop, which calculates the frequency (omega)
            for (int i = 0; i < filterResponse.numberDataPoints; i++)
            {
                // Pre-calculate complex omega_T
                Complex c_omega_T = i * loopConstant;

                // Inner loop, which calculates the summation series
                // Set sum to 0.0, getting it ready for the summation
                Complex sum = 0;
                for (int k = 0; k < filterKernel.Length; k++)
                    sum += filterKernel[k] * Complex.Exp(k * c_omega_T);

                // Calculate the linear amplitude response (gain)
                // at the current frequency
                filterResponse.amplitudeLinear[i] = Complex.Abs(sum);

                // Calculate the phase response at the current frequency
                filterResponse.phaseRadians[i] = sum.Phase;

                // Calculate and store frequency at each i data point
                filterResponse.frequency[i] =
                    ((double)i / (double)(filterResponse.numberDataPoints - 1))
                        * nyquist;
            }

            // Calculate the amplitude response in dB
            filterResponse.amplitudeDB =
                scaleToDecibels(filterResponse.amplitudeLinear);

            // Calculate the unwrapped phase (in radians)
            filterResponse.unwrappedPhase =
                calculateUnwrappedPhase(filterResponse.phaseRadians);

            // Calculate the group delay (in seconds)
            calculateGroupDelay(filterKernel, filterResponse);

            // Calculate the phase delay (in seconds)
            filterResponse.phaseDelay = calculatePhaseDelay(filterResponse);

            // Return the calculated filter response
            return filterResponse;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       scaleToDecibels
        //
        //  Arguments:      input:	The real vector containing linear values.
        //
        //  Returns:        A pointer to a newly created real vector that contains
        //                  the values scaled to decibels.
        //
        //  Description:    This function converts a real vector containing linearly-
        //                  scale values to a newly created real vector containing the
        //                  values scaled to decibels. 1.0 is the reference value used
        //                  for the conversion.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] scaleToDecibels(double[] input)
        {
            // Make sure the vector pointer is not null
            if (input == null)
                throw new ArgumentNullException("input");

            // Create a real vector to hold the scaled vector
            double[] scaledVector = new double[input.Length];

            // Scale each element of the input vector, assuming 1.0 is the
            // reference value for the conversion.
            for (int i = 0; i < input.Length; i++)
                scaledVector[i] = convertToDB(input[i]);

            // Return the newly created scaled vector
            return scaledVector;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       convertToDB
        //
        //  Arguments:      value:     The linear value to be converted.
        //
        //  Returns:        The value converted to a decibel scale.
        //
        //  Description:    This function converts a linear real value, assumed to
        //                  be scaled to 1.0, and converts it to a decibel value.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double convertToDB(double value)
        {
            return (double)20.0 * Math.Log10(value);
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateUnwrappedPhase
        //
        //  Arguments:      phaseRadians:     A real vector containing the wrapped
        //                                    phase response in radians.
        //
        //  Returns:        A real vector containing the unwrapped phase.
        //
        //  Description:    This function calculates the unwrapped phase response
        //                  from the inputted wrapped phase response. It does so by
        //                  adding some multiple of TAU to the unwrapped phase, thus
        //                  guaranteeing continuity from point to point.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] calculateUnwrappedPhase(double[] phaseRadians)
        {
            // Make sure the vector pointer is not null
            if (phaseRadians == null)
                throw new ArgumentNullException("phaseRadians");

            // Create a real vector to hold the unwrapped phase vector
            double[] unwrappedPhase = new double[phaseRadians.Length];

            // The first point of all phase signals is zero
            unwrappedPhase[0] = 0.0;

            // Loop to do the unwrapping
            for (int i = 1; i < phaseRadians.Length; i++)
            {
                double c =
                 Math.Floor((unwrappedPhase[i - 1] - phaseRadians[i]) / Constants.TAU);
                unwrappedPhase[i] = phaseRadians[i] + c * Constants.TAU;
            }

            // Return the newly created unwrapped phase vector
            return unwrappedPhase;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculatePhaseDelay
        //
        //  Arguments:      filterResponse:     A pointer to the structure containing
        //                                      the filter's response.
        //
        //  Returns:        A real vector of the calculated phase delays (in seconds).
        //
        //  Description:    This function calculates the phase delay (in seconds) at
        //                  each specified frequency (in Hz) using the corresponding
        //                  unwrapped phase value (in radians). It does so by dividing
        //                  the unwrapped phase value by -2 * PI * f. Note that the
        //                  phase delay at f = 0 is a special case, and is the same
        //                  as the group delay. It cannot be calculated directly, since
        //                  we would be dividing by 0. This function assumes that the
        //                  group delay has already been calculated.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] calculatePhaseDelay(FilterResponse filterResponse)
        {
            // Make sure we have valid pointers to real vectors
            if (filterResponse == null)
                throw new ArgumentNullException("filterResponse");
            if (filterResponse.frequency == null)
                throw new ArgumentNullException("filterResponse.frequency");
            if (filterResponse.unwrappedPhase == null)
                throw new ArgumentNullException("filterResponse.unwrappedPhase");
            if (filterResponse.groupDelay == null)
                throw new ArgumentNullException("filterResponse.groupDelay");

            // Make sure the vectors are of the same length
            if (filterResponse.frequency.Length !=
                   filterResponse.unwrappedPhase.Length)
                throw new ArgumentException("filterResponse.frequency length must be equal to filterResponse.unwrappedPhase length", "" + filterResponse.unwrappedPhase.Length);

            // Create a real vector to hold the phase delay vector
            double[] phaseDelay =
                new double[filterResponse.frequency.Length];

            // The phase delay at 0 Hz (DC) is a special case. It is the same as the
            // group delay at this frequency. We assume the group delays has already
            // been calculated.
            phaseDelay[0] = filterResponse.groupDelay[0];

            // Calculate the phase delay at each specified frequency
            for (int i = 1; i < filterResponse.frequency.Length; i++)
            {
                // Divide the unwrapped phase by -2 * PI * f
                phaseDelay[i] = filterResponse.unwrappedPhase[i] /
                                         (-Constants.TAU * filterResponse.frequency[i]);
            }

            // Return the newly created phase delay vector
            return phaseDelay;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateDCGroupDelay
        //
        //  Arguments:      filterKernel:       A pointer to the filter kernel.
        //                  filterResponse:     A pointer to the structure holding the
        //                                      filter response.
        //
        //  Returns:        The calculated group delay at 0 Hz (DC).
        //
        //  Description:    This function calculates the group delay at f = 0 Hz (DC).
        //                  This has to be calculated as a special case, and is done by
        //                  first calculating the filter's phase at f1 = 0 and
        //                  f2 = 0.0001. The deriviative at f1 = 0 is approximated by
        //                  calculating -delta(phi(omega)) / delta(omega).
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double calculateDCGroupDelay(double[] filterKernel,
                                     FilterResponse filterResponse)
        {
            double DCfrequency = 0.0, f2 = 0.0001, DCPhase, phase2;

            // Make sure we have valid pointers
            if (filterKernel == null)
                throw new ArgumentNullException("filterKernel");
            if (filterResponse == null)
                throw new ArgumentNullException("filterResponse");
            if (filterResponse.unwrappedPhase == null)
                throw new ArgumentNullException("filterResponse.unwrappedPhase");

            // Get the phase (in radians) at f = 0 (DC)
            DCPhase = filterResponse.unwrappedPhase[0];

            // Calculate the sampling increment T, which is 1 / Fs
            double T = 1.0 / filterResponse.sampleRate;

            // Precalculate the delta(omega), which is 2 * PI * delta(f)
            double deltaOmega = Constants.TAU * (f2 - DCfrequency);

            // Calculate filter response at f2
            // Pre-calculate complex omega * T
            Complex complex_omega_T = -Complex.ImaginaryOne * Constants.TAU * f2 * T;

            // Set sum to 0.0, getting it ready for the summation
            Complex sum = 0;

            // Calculate the summation series
            for (int k = 0; k < filterKernel.Length; k++)
                sum += filterKernel[k] * Complex.Exp(k * complex_omega_T);

            // Calculate the phase response (in radians) at the f2 frequency
            phase2 = sum.Phase;

            // Calculate and return the group delay at f = 0, defined as:
            //    -delta(phase(omega) / delta(omega)
            return -(phase2 - DCPhase) / deltaOmega;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateGroupDelay
        //
        //  Arguments:      filterKernel:       A pointer to the filter kernel.
        //                  filterResponse:     A pointer to the structure holding the
        //                                      filter response.
        //
        //  Returns:        void
        //
        //  Description:    This function calculates the group delay at each frequency
        //                  specified in the filter response. The group delay is defined
        //                  as:  - d phi(omega) / d omega. The derivative is
        //                  approximated by calculating:
        //                     delta(phi(omega) / delta(omega)
        //                  Note that we use the unwrapped phase vector to get values
        //                  of phi.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void calculateGroupDelay(double[] filterKernel,
                             FilterResponse filterResponse)
        {
            // Make sure we have valid pointers to real vectors
            if (filterKernel == null)
                throw new ArgumentNullException("filterKernel");
            if (filterResponse == null)
                throw new ArgumentNullException("filterResponse");
            if (filterResponse.frequency == null)
                throw new ArgumentNullException("filterResponse.frequency");
            if (filterResponse.unwrappedPhase == null)
                throw new ArgumentNullException("filterResponse.unwrappedPhase");

            // Make sure the vectors are of the same length
            if (filterResponse.frequency.Length !=
                   filterResponse.unwrappedPhase.Length)
                throw new ArgumentException("filterResponse.frequency length must be equal to filterResponse.unwrappedPhase length", "" + filterResponse.unwrappedPhase.Length);

            // Create a real vector to hold the group delay vector
            filterResponse.groupDelay =
                new double[filterResponse.frequency.Length];

            // Precalculate the denominator, which is 2 * PI * delta(f)
            double deltaOmega = Constants.TAU * filterResponse.binSize;

            // The group delay at 0 Hz (DC) is a special case
            filterResponse.groupDelay[0] =
                calculateDCGroupDelay(filterKernel, filterResponse);

            // Loop to calculate remaining elements
            for (int i = 1; i < filterResponse.frequency.Length; i++)
            {
                // Calculate delta(phase)
                double deltaPhase = filterResponse.unwrappedPhase[i] -
                                    filterResponse.unwrappedPhase[i - 1];

                // Calculate the group delay, defined as:
                //     -delta(phase(omega) / delta(omega)
                filterResponse.groupDelay[i] = -deltaPhase / deltaOmega;
            }
        }

    }
}
