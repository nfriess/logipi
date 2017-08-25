using System;
using System.Numerics;

namespace DigitalCrossover
{
    class FourierAnalysis
    {

        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexScaledDFT
        //
        //  Arguments:      x:     The complex signal to be transformed.
        //
        //  Returns:        A pointer to a complex vector containing the scaled
        //                  rectangular complex frequency spectrum.
        //
        //  Description:    This function does the forward complex discrete fourier
        //                  transform on the input complex vector containing the time
        //                  series x[].  This function does an out-of-place transform,
        //                  and returns a newly-allocated complex vector containing
        //                  the complex frequency spectrum X[] in rectangular form.
        //                  Note that scaling by 1/N is also done in this function,
        //                  making this implementation consistent with the definition
        //                  of the DFT in Smith, p. 578.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Complex[] complexScaledDFT(Complex[] x)
        {
            // Make sure the vector pointer is not null
            if (x == null)
                throw new ArgumentNullException("x");

            // Make sure the vector length is 1 or greater
            if (x.Length < 1)
                throw new ArgumentOutOfRangeException("x.Length", "" + x.Length);

            // Calculate the constant omega (is negative for the DFT)
            Complex omega = (-Constants.TAU / (double)(x.Length)) * Complex.ImaginaryOne;

            // Allocate a complex vector to hold the transform result.
            // It has the same length as the input vector.
            Complex[] X = new Complex[x.Length];

            // Perform the complex DFT
            for (int k = 0; k < x.Length; k++)
            {
                // Initialize the kth element to 0, to prepare for the summation
                X[k] = 0;

                // Precalculate omega * k
                Complex omega_k = omega * k;

                // Do the summation
                for (int n = 0; n < x.Length; n++)
                    X[k] += x[n] * Complex.Exp(omega_k * n);

                // Scale the value by 1/N
                X[k] /= (double)(x.Length);
            }

            // Return a pointer to the complex vector holding X
            return X;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexUnscaledIDFT
        //
        //  Arguments:      X:     The complex frequency spectrum to be transformed.
        //
        //  Returns:        A pointer to the rectangular complex time series.
        //
        //  Description:    This function does the inverse complex discrete fourier
        //                  transform on the input complex vector containing the
        //                  frequency spectrum X[] (in rectangular form).  This
        //                  function does an out-of-place transform, and returns a
        //                  newly-allocated complex vector containing the complex time
        //                  series x[] in rectangular form.  Note that scaling by 1/N
        //                  is NOT done in this function, making this implementation
        //                  consistent with the definition of the IDFT in Smith, p. 578.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Complex[] complexUnscaledIDFT(Complex[] X)
        {
            // Make sure the vector pointer is not null
            if (X == null)
                throw new ArgumentNullException("X");

            // Make sure the vector length is 1 or greater
            if (X.Length < 1)
                throw new ArgumentOutOfRangeException("X.Length", "" + X.Length);

            // Calculate the constant omega (is positive for the IDFT)
            Complex omega = (+Constants.TAU / (double)(X.Length)) * Complex.ImaginaryOne;

            // Allocate a complex vector to hold the transform result.
            // It has the same length as the input vector.
            Complex[] x = new Complex[X.Length];

            // Perform the complex IDFT
            for (int k = 0; k < X.Length; k++)
            {
                // Initialize the kth element to 0, to prepare for the summation
                x[k] = 0;

                // Precalculate omega * k
                Complex omega_k = omega * k;

                // Do the summation
                for (int n = 0; n < X.Length; n++)
                    x[k] += X[n] * Complex.Exp(omega_k * n);
            }

            // Return a pointer to the complex vector holding x
            return x;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexScaledFFT
        //
        //  Arguments:      x:      The input complex vector containing the signal
        //                          to transform.
        //
        //  Returns:        void
        //
        //  Description:    This function does the forward complex fast fourier
        //                  transform on the input complex vector containing the time
        //                  series x[].  This function does an in-place, decimation-in-
        //                  time transform, with the input complex vector replaced with
        //                  the complex frequency spectrum X[] in rectangular form.
        //                  Note that scaling by 1/N is also done in this function,
        //                  making this implementation consistent with the definition
        //                  of the DFT in Smith, p. 578.  This algorithm is based on
        //                  the code on p. 608 of Oppenheim and Schafer, and implements
        //                  the algorithm described in Figures 9.9 and 9.10 of that
        //                  book.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static void complexScaledFFT(Complex[] x)
        {
            // Make sure the vector pointer is not null
            if (x == null)
                throw new ArgumentNullException("x");

            // Make sure the vector length is 1 or greater
            if (x.Length < 1)
                throw new ArgumentOutOfRangeException("x.Length", "" + x.Length);

            //Make sure length of vector is a power of 2
            if (!Utility.isPowerOf2(x.Length))
                throw new ArgumentException("x.Length must be a power of 2", "x");

            // Calculate the length of the vector divided by 2
            int halfLength = x.Length >> 1;

            // Do the bit reversal sorting of the input time series
            for (int i = 0, j = 0; i < x.Length - 1; i++)
            {
                if (i < j)
                {
                    // Swap elements at indices i and j
                    Complex temp = x[j];
                    x[j] = x[i];
                    x[i] = temp;
                }
                int k = halfLength;
                while (k <= j)
                {
                    j -= k;
                    k >>= 1;    // Same as k /= 2
                }
                j += k;
            }


            // Compute the FFT
            Complex omega = -Constants.PI * Complex.ImaginaryOne;   // negative for forward FFT
            for (int skip = 2, gap = 1; skip <= x.Length; skip <<= 1, gap <<= 1)
            {
                Complex u = 1;
                Complex w = Complex.Exp(omega / gap);

                for (int j = 0; j < gap; j++)
                {
                    for (int i = j; i < x.Length; i += skip)
                    {
                        int ip = i + gap;
                        // Do butterfly calculation
                        Complex temp = x[ip] * u;
                        x[ip] = x[i] - temp;
                        x[i] = x[i] + temp;
                    }
                    u *= w;
                }
            }

            // Scale each element by n
            for (int i = 0; i < x.Length; i++)
                x[i] /= x.Length;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexUnscaledFFT
        //
        //  Arguments:      x:      The input complex vector containing the signal
        //                          to transform.
        //
        //  Returns:        void
        //
        //  Description:    This function does the forward complex fast fourier
        //                  transform on the input complex vector containing the time
        //                  series x[].  This function does an in-place, decimation-in-
        //                  time transform, with the input complex vector replaced with
        //                  the complex frequency spectrum X[] in rectangular form.
        //                  Note that scaling by 1/N is NOT done in this function.
        //                  This algorithm is based on the code on p. 608 of Oppenheim
        //                  and Schafer, and implements the algorithm described in 
        //                  Figures 9.9 and 9.10 of that book.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static void complexUnscaledFFT(Complex[] x)
        {
            // Make sure the vector pointer is not null
            if (x == null)
                throw new ArgumentNullException("x");

            // Make sure the vector length is 1 or greater
            if (x.Length < 1)
                throw new ArgumentOutOfRangeException("x.Length", "" + x.Length);

            //Make sure length of vector is a power of 2
            if (!Utility.isPowerOf2(x.Length))
                throw new ArgumentException("x.Length must be a power of 2", "x");

            // Calculate the length of the vector divided by 2
            int halfLength = x.Length >> 1;

            // Do the bit reversal sorting of the input time series
            for (int i = 0, j = 0; i < x.Length - 1; i++)
            {
                if (i < j)
                {
                    // Swap elements at indices i and j
                    Complex temp = x[j];
                    x[j] = x[i];
                    x[i] = temp;
                }
                int k = halfLength;
                while (k <= j)
                {
                    j -= k;
                    k >>= 1;    // Same as k /= 2
                }
                j += k;
            }


            // Compute the FFT
            Complex omega = -Constants.PI * Complex.ImaginaryOne;   // negative for forward FFT
            for (int skip = 2, gap = 1; skip <= x.Length; skip <<= 1, gap <<= 1)
            {
                Complex u = 1;
                Complex w = Complex.Exp(omega / gap);

                for (int j = 0; j < gap; j++)
                {
                    for (int i = j; i < x.Length; i += skip)
                    {
                        int ip = i + gap;
                        // Do butterfly calculation
                        Complex temp = x[ip] * u;
                        x[ip] = x[i] - temp;
                        x[i] = x[i] + temp;
                    }
                    u *= w;
                }
            }
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexScaledIFFT
        //
        //  Arguments:      X:      The input complex vector containing the signal
        //                          to transform.
        //
        //  Returns:        void
        //
        //  Description:    This function does the inverse complex fast fourier
        //                  transform on the input complex vector containing the
        //                  frequency series X[].  This function does an in-place,
        //                  decimation-in-time transform, with the input complex vector
        //                  replaced with the complex time series x[] in rectangular
        //                  form. Note that scaling by 1/N is also done in this
        //                  function. This algorithm is based on the code on p. 608
        //                  of Oppenheim and Schafer, and implements the algorithm
        //                  described in Figures 9.9 and 9.10 of that book.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static void complexScaledIFFT(Complex[] X)
        {
            // Make sure the vector pointer is not null
            if (X == null)
                throw new ArgumentNullException("X");

            // Make sure the vector length is 1 or greater
            if (X.Length < 1)
                throw new ArgumentOutOfRangeException("X.Length", "" + X.Length);

            //Make sure length of vector is a power of 2
            if (!Utility.isPowerOf2(X.Length))
                throw new ArgumentException("X.Length must be a power of 2", "X");

            // Calculate the length of the vector divided by 2
            int halfLength = X.Length >> 1;

            // Do the bit reversal sorting of the input frequency series
            for (int i = 0, j = 0; i < X.Length - 1; i++)
            {
                if (i < j)
                {
                    // Swap elements at indices i and j
                    Complex temp = X[j];
                    X[j] = X[i];
                    X[i] = temp;
                }
                int k = halfLength;
                while (k <= j)
                {
                    j -= k;
                    k >>= 1;    // Same as k /= 2
                }
                j += k;
            }


            // Compute the IFFT
            Complex omega = +Constants.PI * Complex.ImaginaryOne;   // positive for inverse FFT
            for (int skip = 2, gap = 1; skip <= X.Length; skip <<= 1, gap <<= 1)
            {
                Complex u = 1;
                Complex w = Complex.Exp(omega / gap);

                for (int j = 0; j < gap; j++)
                {
                    for (int i = j; i < X.Length; i += skip)
                    {
                        int ip = i + gap;
                        // Do butterfly calculation
                        Complex temp = X[ip] * u;
                        X[ip] = X[i] - temp;
                        X[i] = X[i] + temp;
                    }
                    u *= w;
                }
            }

            // Scale each element by n
            for (int i = 0; i < X.Length; i++)
                X[i] /= X.Length;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       complexUnscaledIFFT
        //
        //  Arguments:      X:      The input complex vector containing the signal
        //                          to transform.
        //
        //  Returns:        void
        //
        //  Description:    This function does the inverse complex fast fourier
        //                  transform on the input complex vector containing the 
        //                  frequency series X[].  This function does an in-place, 
        //                  decimation-in-time transform, with the input complex vector
        //                  replaced with the complex time series x[] in rectangular 
        //                  form. Note that scaling by 1/N is NOT done in this function,
        //                  making this implementation consistent with the definition
        //                  of the IDFT in Smith, p. 578.  This algorithm is based on
        //                  the code on p. 608 of Oppenheim and Schafer, and implements
        //                  the algorithm described in Figures 9.9 and 9.10 of that
        //                  book.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static void complexUnscaledIFFT(Complex[] X)
        {
            // Make sure the vector pointer is not null
            if (X == null)
                throw new ArgumentNullException("X");

            // Make sure the vector length is 1 or greater
            if (X.Length < 1)
                throw new ArgumentOutOfRangeException("X.Length", "" + X.Length);

            //Make sure length of vector is a power of 2
            if (!Utility.isPowerOf2(X.Length))
                throw new ArgumentException("X.Length must be a power of 2", "X");

            // Calculate the length of the vector divided by 2
            int halfLength = X.Length >> 1;

            // Do the bit reversal sorting of the input frequency series
            for (int i = 0, j = 0; i < X.Length - 1; i++)
            {
                if (i < j)
                {
                    // Swap elements at indices i and j
                    Complex temp = X[j];
                    X[j] = X[i];
                    X[i] = temp;
                }
                int k = halfLength;
                while (k <= j)
                {
                    j -= k;
                    k >>= 1;    // Same as k /= 2
                }
                j += k;
            }


            // Compute the IFFT
            Complex omega = +Constants.PI * Complex.ImaginaryOne;   // positive for inverse FFT
            for (int skip = 2, gap = 1; skip <= X.Length; skip <<= 1, gap <<= 1)
            {
                Complex u = 1;
                Complex w = Complex.Exp(omega / gap);

                for (int j = 0; j < gap; j++)
                {
                    for (int i = j; i < X.Length; i += skip)
                    {
                        int ip = i + gap;
                        // Do butterfly calculation
                        Complex temp = X[ip] * u;
                        X[ip] = X[i] - temp;
                        X[i] = X[i] + temp;
                    }
                    u *= w;
                }
            }
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       magnitudeSpectrum
        //
        //  Arguments:      X:	The complex frequency spectrum in rectangular form.
        //                      The length of X must be an even number >= 2.
        //
        //  Returns:        A pointer to a real vector containing the magnitude
        //                  spectrum. The 0th element containes the magnitude of the
        //                  DC component, and each ith component contains the magnitude
        //                  of each ith harmonic, up to the nyquist frequency.
        //
        //  Description:    This function calculates the magnitude spectrum of the
        //                  inputted rectangular complex spectrum. The magnitude
        //                  spectrum is returned in a newly allocated real vector.
        //                  The length of the complex spectrum must be an even number,
        //                  so that the magnitude spectrum describes the strength of
        //                  harmonics.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static double[] magnitudeSpectrum(Complex[] X)
        {
            // Make sure the vector pointer is not null
            if (X == null)
                throw new ArgumentNullException("X");

            // Make sure the vector length is 2 or greater, and is even
            if (X.Length < 2)
                throw new ArgumentOutOfRangeException("X.Length", "" + X.Length);
            if ((X.Length % 2) != 0)
                throw new ArgumentException("X.Length must be even", "X");

            // Allocate a real vector to hold the magnitude spectrum.
            // Its length is N/2 + 1 (assumes integer division).
            double[] vector = new double[(X.Length / 2) + 1];

            // The DC component is handled separately, and is simply the absolute
            // value of the 0th element of the complex spectrum
            vector[0] = Complex.Abs(X[0]);

            // The N/2 (or nyquist) frequency component is also a special case, and
            // is the absolute value of the N/2 element of the complex spectrum
            int nyquist = (X.Length / 2);
            vector[nyquist] = Complex.Abs(X[nyquist]);

            // Calculate the remaining frequency components by taking the absolute
            // value of each complex spectrum element, and then add the positive and
            // negative frequency components together.
            for (int i = 1, j = X.Length - 1; i < nyquist; i++, j--)
                vector[i] = Complex.Abs(X[i]) + Complex.Abs(X[j]);

            // Return a pointer to the real vector containing the magnitude spectrum
            return vector;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       phaseSpectrum
        //
        //  Arguments:      X:	                The complex frequency spectrum in
        //                                      rectangular form. The length of X must
        //                                      be an even number >= 2.
        //                  magnitudeSpectrum:  A real vector containing the calculated
        //                                      magnitude spectrum of X.
        //
        //  Returns:        A pointer to a real vector containing the phase
        //                  spectrum. The 0th element containes the phase of the
        //                  DC component, and each ith component contains the phase
        //                  of each ith harmonic, up to the nyquist frequency.
        //
        //  Description:    This function calculates the phase spectrum of the
        //                  inputted rectangular complex spectrum.  The phase
        //                  spectrum is returned in a newly allocated real vector.
        //                  The length of the complex spectrum must be an even number,
        //                  so that the phase spectrum describes the phase angle of
        //                  harmonics.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static double[] phaseSpectrum(Complex[] X, double[] magnitudeSpectrum)
        {
            // Make sure the vector pointer is not null
            if (X == null)
                throw new ArgumentNullException("X");
            if (magnitudeSpectrum == null)
                throw new ArgumentNullException("magnitudeSpectrum");

            // Make sure the X vector length is 2 or greater, and is even
            if (X.Length < 2)
                throw new ArgumentOutOfRangeException("X.Length", "" + X.Length);
            if ((X.Length % 2) != 0)
                throw new ArgumentException("X.Length must be even", "X");

            // Make sure the magnitudeSpectrum vector is the correct length
            if (magnitudeSpectrum.Length != ((X.Length / 2) + 1))
                throw new ArgumentException("magnitudeSpectrum.Length depends on X.Length", "magnitudeSpectrum");

            // Allocate a real vector to hold the phase spectrum.
            // Its length is N/2 + 1 (assumes integer division).
            double[] vector = new double[(X.Length / 2) + 1];

            // Calculate the phase components by taking the argument of each complex
            // spectrum element.  For a purely real signal, we only need to use the 
            // components from DC up to and including the nyquist component, since
            // the phase is symmetrical.
            for (int i = 0; i <= (X.Length / 2); i++)
            {
                // Only assign a non-zero phase value if the corresponding magnitude 
                // value is also "non-zero" (i.e. greater than a tiny epsilon value)
                if (magnitudeSpectrum[i] > (0.0 + Constants.ZERO_EPSILON))
                {
                    vector[i] = X[i].Phase;
                }
            }

            // Return a pointer to the real vector containing the phase spectrum
            return vector;
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       DCOffset
        //
        //  Arguments:      magnitudeSpectrum:  A real vector containing the calculated
        //                                      magnitude spectrum of the signal.
        //                  phaseSpectrum:      A real vector containing the calculated
        //                                      phase spectrum of the signal.
        //
        //  Returns:        Returns the calculated DC Offset for an analyzed signal.
        //
        //  Description:    This function calculates the DC Offset for a signal, given
        //                  that signal's magnitude and phase spectra. It calculates
        //                  the offset by examining the magnitude and phase of harmonic
        //                  zero.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static double DCOffset(double[] magnitudeSpectrum, double[] phaseSpectrum)
        {
            double DCOffset;


            // Make sure the vector pointers are not null
            if (magnitudeSpectrum == null)
                throw new ArgumentNullException("magnitudeSpectrum");
            if (phaseSpectrum == null)
                throw new ArgumentNullException("phaseSpectrum");

            // Calculate the DC Offset, given the calculated magnitude and phase
            // spectra. If the phase of harmonic 0 is 0 (i.e. less than 0 + an epsilon,
            // then the DC offset is the positive magnitude of harmonic 0.
            if (Math.Abs(phaseSpectrum[0]) < (0.0 + Constants.PHASE_EPSILON))
            {
                DCOffset = +magnitudeSpectrum[0];
            }
            else
            {
                // If the phase is +- 180 degrees, then the DC offset is the
                // negative magnitude of harmonic 0
                DCOffset = -magnitudeSpectrum[0];
            }

            return DCOffset;
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

        public static double[] scaleToDecibels(double[] input)
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

        public static double convertToDB(double value)
        {
            return (double)20.0 * Math.Log10(value);
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       padConvertSignal
        //
        //  Arguments:      signal:     A real signal passed in as a real vector.
        //
        //  Returns:        A complex signal (i.e. a complex vector), padded with zeroes
        //                  as necessary to fill out the length of the signal to the
        //                  next higher power of 2.
        //
        //  Description:    This function takes in a real signal (i.e. a real vector),
        //                  pads the length of the signal so that the new length is a
        //                  power of 2 and is greater than or equal to the original
        //                  length of the signal. The real signal is also converted to
        //                  a complex signal (i.e. a complex vector) by setting the
        //                  imaginary parts of the vector elements to zero. This
        //                  function is intended to by used when calculating the
        //                  magnitude and phase spectra of a signal.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Complex[] padConvertSignal(double[] signal)
        {
            // Make sure the argument is valid
            if (signal == null)
                throw new ArgumentNullException("signal");

            // Make sure the length of the signal is 2 or greater
            if (signal.Length < 2)
                throw new ArgumentOutOfRangeException("signal.Length", "" + signal.Length);

            // Find the length of the new complex signal
            int length = Utility.nextPowerOf2(signal.Length);

            // Allocate a complex vector to hold the new complex signal
            // Note that all elements of the vector are initialized to zero
            Complex[] complexSignal = new Complex[length];

            // Copy the signal into the complex signal, converting the
            // real numbers into complex numbers with a zero imaginary part
            for (int i = 0; i < signal.Length; i++)
                complexSignal[i] = signal[i];

            // Return the newly created complex signal
            return complexSignal;
        }



    }
}
