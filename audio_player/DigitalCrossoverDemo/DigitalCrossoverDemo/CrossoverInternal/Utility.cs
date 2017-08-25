using System;

namespace DigitalCrossover
{
    class Utility
    {


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       isPowerOf2
        //
        //  Arguments:      value:     The integer value being tested. This should be
        //                             a positive integer, 2 or greater.
        //
        //  Returns:        A boolean true or false
        //
        //  Description:    This function tests the integer argument value, and returns
        //                  true if it is a number evenly divisible by a some power of
        //                  2 (in other words, value = 2^n, where n is a whole positive
        //                  integer). Otherwise, the function returns false.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static bool isPowerOf2(int value)
        {
            // Make sure the argument is a positive integer, >= 2
            if (value < 2)
                throw new ArgumentOutOfRangeException("value", "" + value);

            // Find the log2 of the argument value
            double log2Value = Math.Log((double)value) / Math.Log(2.0);

            // Returns true if the value is an even power of two (i.e. if value = 2^n,
            // where n is a whole positive integer)
            return ((log2Value - (int)log2Value) == 0);
        }



        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       nextPowerOf2
        //
        //  Arguments:      value:     The integer value being tested. This should be a
        //                             positive integer, 2 or greater.
        //
        //  Returns:        An integer value which is a power of 2, and is equal to or
        //                  greater than the argument value.
        //
        //  Description:    This function take the argument value, and finds a
        //                  positive integer value that is greater than or equal to this
        //                  value, and which is also a power of 2.
        //                  
        ////////////////////////////////////////////////////////////////////////////////

        public static int nextPowerOf2(int value)
        {
            // Make sure the argument is a positive integer, >= 2
            if (value < 2)
                throw new ArgumentOutOfRangeException("value", "" + value);

            // If the value is already a power of 2, then simply return the value
            if (isPowerOf2(value))
                return value;

            // Otherwise, find the next power of 2
            return (int)Math.Pow(2, (int)Math.Ceiling(Math.Log((double)value) / Math.Log(2.0)));
        }

    }
}
