using System;
using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using System.Text;
using System.Threading.Tasks;

namespace DeemphasisInternal
{
    class Deemphasis
    {

        public int length;
        public double sampleRate;
        public double binSize;
        public bool correctPhase;
        public double[] filterKernel;
        public IdealResponse idealFilterResponse;
        public bool doAnalysis;
        public IdealResponse actualFilterResponse;
        public Deviation deviation;

        private Deemphasis(int length, double sampleRate, double binSize, bool correctPhase, bool doAnalysis)
        {
            this.length = length;
            this.sampleRate = sampleRate;
            this.binSize = binSize;
            this.correctPhase = correctPhase;
            this.filterKernel = null;
            this.idealFilterResponse = null;
            this.doAnalysis = doAnalysis;
            this.actualFilterResponse = null;
            this.deviation = null;
        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createDeemphasisFilter
        //
        //  Arguments:      length:         Filter kernel length.
        //                  sampleRate:     System sample rate in Hertz. Must
        //									be greater than 0.
        //                  doAnalysis:     If set to true, this function will
        //                                  calculate and print the filter response.
        //                  correctPhase:   If set to true, this function corrects the
        //                                  phase distortion produced by the pre-
        //                                  emphasis filter.
        //
        //  Returns:        Returns a pointer to a struct containing pointer to the
        //					filter kernel plus other information
        //
        //  Description:    This function creates a filter kernel that implements
        //                  the de-emphasis filter needed to compensate for the pre-
        //                  emphasis filtering that is present on some CD recordings.
        //                  The filter will correct the frequency response of the input
        //                  to produce an output that should have a spectrum identical
        //                  to the original recording before an emphasis filter was
        //                  applied. If the correctPhase switch is set to true, then
        //                  the phase is also corrected; if not, a linear phase filter
        //                  is created.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Deemphasis createDeemphasisFilter(int length, double sampleRate,
                                             bool correctPhase, bool doAnalysis)
        {
            // Make sure the length of the filter is at least 8 samples
            if (length < 8)
                throw new ArgumentOutOfRangeException("length", "" + length);

            // Make sure the length of the filter is power of 2
            if (!Utility.isPowerOf2(length))
                throw new ArgumentOutOfRangeException("length", "" + length);

            // Make sure the sample rate is greater than 0
            if (sampleRate <= 0)
                throw new ArgumentOutOfRangeException("sampleRate", "" + sampleRate);

            // Calculate the bin size
            double binSize = sampleRate / (double)length;

            // Make sure the binsize is > 0 and <= 1/4 of the sample rate. This
            // guarantees at least 3 data points when calculating the filter
            // response, i.e. at DC, nyquist/2, and nyquist.
            if ((binSize <= 0) || (binSize > sampleRate / 4))
                throw new ArgumentOutOfRangeException("binSize", "" + binSize);

            // Allocate memory for the deemphasis filter struct
            Deemphasis deemphasis = new Deemphasis(length, sampleRate, binSize,
                correctPhase, doAnalysis);

            // Calculate the ideal frequency response of the de-emphasis filter
            deemphasis.idealFilterResponse =
                IdealResponse.calculateIdealResponse(length, sampleRate);

            // Create the de-emphasis filter kernel, using the ideal filter response
            deemphasis.filterKernel =
                createFilterKernel(deemphasis.idealFilterResponse,
                                   deemphasis.correctPhase);

            // If we are doing analysis, then calculate the response and deviation
            // of this filter kernel, and print out the results
            if (deemphasis.doAnalysis)
            {
                // Calculate the actual filter response
                //deemphasis.actualFilterResponse =
                //    IdealResponse.calculateIdealResponse(deemphasis.filterKernel,
                //                            sampleRate, binSize);

                // Calculate and print out deviations for
                // amplitude (dB), phase Delay (s), group delay (s)
                //deemphasis.deviation = Deviation.calculateDeviation(deemphasis);
            }

            // Return a pointer to the newly created deemphasis struct
            return deemphasis;
        }

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       createFilterKernel
        //
        //  Arguments:      idealResponse:     Pointer to the ideal filter response.
        //
        //  Returns:        A pointer to the newly-created filter kernel.
        //
        //  Description:    This function creates a real-valued filter kernel whose
        //                  response closely matches the response of the ideal
        //                  de-emphasis filter, including phase correction.
        //
        ////////////////////////////////////////////////////////////////////////////////

        private static double[] createFilterKernel(IdealResponse idealResponse,
                                 bool correctPhase)
        {
            int i, j;
            double a, b, magnitude;


            // Make sure we have a valid pointer
            if (idealResponse == null)
                throw new ArgumentNullException("idealResponse");

            // Create a complex vector to hold the rotated complex filter response
            Complex[] complexFilterKernel = new Complex[idealResponse.complexResponse.Length];

            // Calculate the number of (positive or negative) harmonics. Since the
            // complex response contains both positive and negative frequencies, this
            // will be 1/2 its length.
            int numberHarmonics = complexFilterKernel.Length / 2;

            // Calculate the position of the DC component
            int DCIndex = numberHarmonics - 1;

            // Rotate and copy the complex response into the vector. We rotate so that
            // the harmonics are ordered as follows:
            //    0 (DC), 1, 2, 3, ..., N-1, N (nyquist), -(N-1), ..., -3, -2, -1
            // First copy from the harmonics ranging from 0 (DC) to N (nyquist)
            // into the vector
            for (i = 0, j = DCIndex; j < complexFilterKernel.Length; i++, j++)
            {
                complexFilterKernel[i] =
                    idealResponse.complexResponse[j];
            }

            // Make note of the position of the sample at the Nyquist frequency
            int nyquistPosition = i - 1;

            // And then copy the harmonics ranging from -(N-1) to -1 into the vector.
            // Note that we assume the value of i is carried over from previous loop.
            for (j = 0; j < DCIndex; i++, j++)
            {
                complexFilterKernel[i] =
                    idealResponse.complexResponse[j];
            }

            // If we are NOT doing phase correction, then we are creating a filter
            // with linear phase. We must use the magnitude for the real part of the
            // complex response, and set the imaginary part to zero.
            if (correctPhase == false)
            {
                for (i = 0; i < complexFilterKernel.Length; i++)
                {
                    a = complexFilterKernel[i].Real;
                    b = complexFilterKernel[i].Imaginary;
                    magnitude = Math.Sqrt((a * a) + (b * b));
                    complexFilterKernel[i] = magnitude + Complex.ImaginaryOne * 0;
                }
            }

            // Correct the complex filter kernel by setting the phase at the nyquist
            // frequency to zero. The imaginary part is zeroed, and the real part
            // is given the full magnitude of the original complex value.
            a = complexFilterKernel[nyquistPosition].Real;
            b = complexFilterKernel[nyquistPosition].Imaginary;
            magnitude = Math.Sqrt((a * a) + (b * b));
            complexFilterKernel[nyquistPosition] = magnitude + Complex.ImaginaryOne * 0;

            // Perform a complex scaled in-place IFFT on the complex response. The
            // result is a complex vector, where all the imaginary components should be
            // 0.0. Note that the IFFT gives imaginary components very close to 0.0,
            // while the IDFT gives a noisier result.
            FourierAnalysis.complexScaledIFFT(complexFilterKernel);

            // Copy the real part of the complex vector into a newly-created real vector
            double[] temp = new double[complexFilterKernel.Length];
            for (i = 0; i < temp.Length; i++)
            {
                temp[i] = complexFilterKernel[i].Real;
            }

            // Rotate the vector by N/2 to create the unwindowed filter kernel
            double[] kernel = new double[temp.Length];
            int midpoint = temp.Length / 2;
            for (i = 0, j = midpoint; j < temp.Length; i++, j++)
            {
                kernel[i] = temp[j];
            }
            for (j = 0; j < midpoint; i++, j++)
            {
                kernel[i] = temp[j];
            }

            // Apply the Blackman-Harris window to the kernel, to reduce aliasing
            // which shows up as ripples in the filter's response
            applyHarrisWindow(kernel);

            // Return a pointer to the newly-calculated filter kernel
            return kernel;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       applyHarrisWindow
        //
        //  Arguments:      vector:     Vector containing the signal. The vector length
        //                              should be a positive integer.
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

            // Make sure the size of the array is a positive integer
            if (vector.Length < 1)
                throw new ArgumentOutOfRangeException("vector.Length", "" + vector.Length);

            // Apply the window to the signal
            for (int i = 0; i < vector.Length; i++)
            {
                vector[i] *= (double)0.35875 -
                (double)0.48829 * Math.Cos((Constants.TAU * i) / (vector.Length - 1)) +
                (double)0.14128 * Math.Cos((2 * Constants.TAU * i) / (vector.Length - 1)) -
                (double)0.01168 * Math.Cos((3 * Constants.TAU * i) / (vector.Length - 1));
            }
        }


    }
}
