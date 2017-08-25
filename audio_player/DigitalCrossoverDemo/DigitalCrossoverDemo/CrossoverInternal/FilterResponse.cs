using System;
using System.Numerics;

namespace DigitalCrossover
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
            return (double)20.0* Math.Log10(value);
        }


    }
}
