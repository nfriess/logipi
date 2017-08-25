using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;

namespace DeemphasisInternal
{
    class IdealResponse
    {

        public int length;
        public double sampleRate;
        public double binSize;
        public double[] frequency;
        public Complex[] complexResponse;
        public double[] amplitudeLinear;
        public double[] amplitudeDB;
        public double[] phaseRadians;
        public double[] phaseDelay;
        public double[] groupDelay;

        // Replaces createIdealResponse(int length)
        public IdealResponse(int length)
        {
            this.length = length;
            this.sampleRate = 0.0;
            this.binSize = 0.0;
            this.frequency = new double[length];
            this.complexResponse = new Complex[length];
            this.amplitudeLinear = new double[length];
            this.amplitudeDB = new double[length];
            this.phaseRadians = new double[length];
            this.phaseDelay = new double[length];
            this.groupDelay = new double[length];
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateIdealResponse
        //
        //  Arguments:      length:         Filter kernel length.
        //                  sampleRate:     System sample rate in Hertz. Must
        //									be greater than 0.
        //
        //  Returns:        A structure that holds the ideal frequency response
        //                  of the de-emphasis filter.
        //
        //  Description:    This function calculates the ideal frequency response of
        //                  the canonical de-emphasis filter needed to correct the pre-
        //                  emphasis used on older compact discs (CDs). It does so by
        //                  inverting the reponse of the pre-emphasis filter. This
        //                  pre-emphasis filter is normally implemented using an op-amp
        //                  in a "non-inverting high-pass shelving amplifier" topology.
        //                  The input voltage is fed into the +input of the op-amp,
        //                  and the output is fed back into the -input through a
        //                  feedback resistor (Rf). This input is also grounded through
        //                  an R1 resistor and C1 capacitor connected in series.
        //
        //                              |\
        //                              | \
        //                              |  \
        //                  Vi ---------|+  \
        //                              |    \
        //                              |     >------.------- Vo
        //                              |    /       |
        //                          .---|-  /        |
        //                          |   |  /         |
        //                          |   | /          |
        //                          |   |/           |
        //                          |        Rf      |
        //                          .------/\/\/-----.
        //                          |
        //                          \
        //                          /
        //                          \ R1
        //                          /
        //                          |
        //                          = C1
        //                          |
        //                          |
        //                         GND
        //
        //                  Rf = 35000 Ohms
        //                  R1 = 15000 Ohms
        //                  C1 = 0.000000001 Farads (1 nF)
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static IdealResponse calculateIdealResponse(int length, double sampleRate)
        {
            // Make sure the length of the filter is at least 8 samples
            if (length < 8)
                throw new ArgumentOutOfRangeException("length", "" + length);

            // Make sure the length of the filter is a power of 2
            if (!Utility.isPowerOf2(length))
                throw new ArgumentOutOfRangeException("length", "" + length);

            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Define constants used for the resistors and capacitor in the original
            // op-amp filter design
            const double R1 = 15000.0;      // Ohms
            const double Rf = 35000.0;      // Ohms
            const double C1 = 0.000000001;  // Farads

            // Calculate the nyquist frequency
            double nyquist = sampleRate / 2.0;

            // Calculate the center index
            int centerIndex = (length / 2);

            // Calculate the offset
            int offset = centerIndex - 1;

            // Calculate the bin size. This is the difference between the frequencies
            // of consecutive vector elements.
            double binSize = nyquist / ((double)centerIndex);

            // Create a structure to hold the desired frequency response
            IdealResponse response = new IdealResponse(length);

            // Set the sample rate and bin size
            response.sampleRate = sampleRate;
            response.binSize = binSize;

            // Calculate the complex frequency response in rectangular form
            for (int i = 0; i < length; i++)
            {
                // Calculate the frequency in Hz
                double f = sampleRate * ((double)(i - offset) / (double)length);

                // Record this in the frequency vector
                response.frequency[i] = f;

                // Calculate the complex response of the ideal de-emphasis filter
                // at this frequency
                response.complexResponse[i] =
                    calculateComplexResponse(f, R1, Rf, C1);
            }

            // Calculate the amplitude and phase responses from the complex response
            calculateAmplitudeAndPhase(response, R1, Rf, C1);

            // Return the filled-in structure
            return response;
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateComplexResponse
        //
        //  Arguments:      frequency:     Frequency in Hz.
        //                  R1:            The resister 1 value in Ohms.
        //                  Rf:            The feedback resistor value in Ohms.
        //                  C1:            The capacitor value in Farads.
        //
        //  Returns:        The complex frequency response at the specified frequency.
        //
        //  Description:    This function calculates the ideal frequency response of the
        //                  de-emphasis filter in rectangular format. It does so by
        //                  calculating the transfer function I(omega), which is the
        //                  inverse of the transfer function H(omega) of the emphasis
        //                  filter.
        //                      The original H(omega) function is derived from the
        //                  canonical design of the non-inverting high-pass shelving
        //                  amplifier for the emphasis filter, using a pole time
        //                  constant of R1 * C1, and a zero time constant of
        //                  (Rf + R1) * C1, where R1 is 35000 ohms, Rf is 15000 ohms,
        //                  and C1 is 1 nanoFarad (or 0.000000001 Farad). H(omega) is
        //                  defined as follows:
        //
        //                                  1 + (Rf + R1) * C1 * omega * j
        //                      H(omega) = --------------------------------
        //                                      1 + R1 * C1 * omega * j
        //
        //                  where j is the imaginary unit, and omega = 2 * PI * f,
        //                  where f is the frequency in Hz.
        //                      I(omega) is the inverse of H(omega), and is defined as
        //                  follows:
        //
        //                                      1 + R1 * C1 * omega * j
        //                      I(omega) = --------------------------------
        //                                  1 + (Rf + R1) * C1 * omega * j
        //
        //                  We rearrange I(omega) to isolate the real and imaginary
        //                  parts, giving:
        //
        //                                  1 + y * z * omega^2        (y - z) * omega
        //                      I(omega) = --------------------- + j -------------------
        //                                   1 + z^2 * omega^2        1 + z^2 * omega^2
        //
        //                  where y = R1 * C1 (i.e. y is the pole time constant), and
        //                  z = (Rf + R1) * C1 (i.e. z is the zero time constant). Thus
        //                  we can now calculate the real and imaginary parts of the
        //                  complex vector using the following:
        //
        //                                     1 + y * z * omega^2
        //                      Re I(omega) = ---------------------
        //                                      1 + z^2 * omega^2
        //
        //
        //                                      (y - z) * omega
        //                      Im I(omega) = -------------------
        //                                     1 + z^2 * omega^2
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static Complex calculateComplexResponse(double frequency, double R1, double Rf,
                                           double C1)
        {
            // Define pole time constant
            double y = R1 * C1;

            // Define the zero time constant
            double z = (Rf + R1) * C1;

            // Calculate the angular frequency
            double omega = Constants.TAU * frequency;

            // Calculate the denominator
            double denominator = 1.0 + (z * z) * (omega * omega);

            // Calculate the complex frequency response
            // First calculate the real part
            Complex result = (1.0 + y * z * omega * omega) / denominator;

            // Secondly, calculate and store the imaginary part
            result += Complex.ImaginaryOne * (((y - z) * omega) / denominator);

            // Return the calculated result
            return result;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateAmplitudeAndPhase
        //
        //  Arguments:      response:     Pointer to the response structure.
        //                  R1:           The resister 1 value in Ohms.
        //                  Rf:           The feedback resistor value in Ohms.
        //                  C1:           The capacitor value in Farads.
        //
        //  Returns:        void
        //
        //  Description:    The function calculates the amplitude response (both linear
        //                  and dB) of the ideal de-emphasis filter. It also calculates
        //                  the phase response (in radians), phase delay (in seconds),
        //                  and group delay (in seconds) of the ideal filter. Note that
        //                  this function assumes that the frequency and complex
        //                  response vectors have already been calculated.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static void calculateAmplitudeAndPhase(IdealResponse response, double R1, double Rf,
                                        double C1)
        {
            // Make sure we have a valid pointer
            if (response == null)
                throw new ArgumentNullException("response");

            // Calculate the magnitude of the frequency response
            for (int i = 0; i < response.complexResponse.Length; i++)
            {
                // Isolate the real and imaginary parts of the complex response
                double a = response.complexResponse[i].Real;
                double b = response.complexResponse[i].Imaginary;

                // Calculate the linear amplitude
                response.amplitudeLinear[i] = Math.Sqrt((a * a) + (b * b));

                // Calculate the dB-scaled amplitude from the linear amplitude
                response.amplitudeDB[i] =
                    FourierAnalysis.convertToDB(response.amplitudeLinear[i]);

                // Calculate the phase response (in radians)
                response.phaseRadians[i] = Math.Atan(b / a);

                // Calculate the phase delay (in seconds)
                if (response.frequency[i] == 0.0)
                {
                    // The phase delay at f = 0 is a special case: it is C1 * Rf
                    response.phaseDelay[i] = C1 * Rf;
                }
                else
                {
                    // The phase delay is phi(f) = - phase(f) / (2 * Pi * f)
                    response.phaseDelay[i] =
                        response.phaseRadians[i] /
                            (-Constants.TAU * response.frequency[i]);
                }

                // Calculate the group delay (in seconds)
                response.groupDelay[i] =
                    groupDelayFunc(response.frequency[i], R1, Rf, C1);
            }
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       groupDelayFunc
        //
        //  Arguments:      f:      Frequency at which to calculate the group delay.
        //                  R1:     The resister 1 value in Ohms.
        //                  Rf:     The feedback resistor value in Ohms.
        //                  C1:     The capacitor value in Farads.
        //
        //  Returns:        The calculated group delay at the specified frequency.
        //
        //  Description:    This function calculates the group delay (in seconds) for
        //                  the given frequency and resistor and capacitor values.
        //                  It does so by calculating the negative of the derivative
        //                  of the phase function:
        //
        //                               d phi(f)
        //                      G(f) = - --------
        //                                  df
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double groupDelayFunc(double f, double R1, double Rf, double C1)
        {
            double omega, omega_2, C1_2, R1_2, Rf_2, a, a_2, b, numerator, denominator;

            // Calculate omega and omega squared
            omega = Constants.TAU * f;
            omega_2 = omega * omega;

            // Calculate the square of the R1, Rf, and C1 constants
            R1_2 = R1 * R1;
            Rf_2 = Rf * Rf;
            C1_2 = C1 * C1;

            // Calculate a term that appears several times in the calculation,
            // as well as its squared value
            a = (C1_2) * (omega_2) * (R1_2) + (C1_2) * (omega_2) * R1 * Rf + 1.0;
            a_2 = a * a;

            // Calculate the term used in the denominator
            denominator = ((C1_2 * omega_2 * Rf_2) / a_2) + 1.0;

            // Calculate another lengthy term
            b = C1 * omega * Rf *
                ((2.0 * C1_2 * omega * R1_2) + (2.0 * C1_2 * omega * R1 * Rf));

            // Calculate the term used in the numerator
            numerator = ((C1 * Rf) / a) - ((b) / a_2);

            // Return the final calculated value
            return numerator / denominator;
        }

    }
}
