using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DeemphasisInternal
{
    class Deviation
    {

        public double[] frequency;
        public double[] amplitudeDB;
        public double[] phaseDelay;
        public double[] groupDelay;
        public double amplitudeDeviationMin;
        public double amplitudeDeviationMax;
        public double phaseDelayDeviationMin;
        public double phaseDelayDeviationMax;
        public double groupDelayDeviationMin;
        public double groupDelayDeviationMax;

        private Deviation()
        {

        }


        ////////////////////////////////////////////////////////////////////////////////
        //
        //  Function:       calculateDeviation
        //
        //  Arguments:      deemphasisFilter:     A pointer to a calculated deemphasis
        //                                        filter.
        //
        //  Returns:        A pointer to a deviation struct.
        //
        //  Description:    This function calculates the deviation between the ideal
        //                  deemphasis filter response and the actual deemphasis filter
        //                  response embodied in the calculated filter kernel. In
        //                  particular, the deviation of the amplitude response (in dB),
        //                  phase delay (in seconds), and group delay (in seconds) is
        //                  calculated.
        //
        ////////////////////////////////////////////////////////////////////////////////

        public static Deviation calculateDeviation(Deemphasis deemphasisFilter)
        {
            int length;

            // Make sure we have valid pointers
            if (deemphasisFilter == null)
                throw new ArgumentNullException("deemphasisFilter");
            if (deemphasisFilter.idealFilterResponse == null)
                throw new ArgumentNullException("deemphasisFilter.idealFilterResponse");
            if (deemphasisFilter.actualFilterResponse == null)
                throw new ArgumentNullException("deemphasisFilter.actualFilterResponse");
            if (deemphasisFilter.idealFilterResponse.frequency == null)
                throw new ArgumentNullException("deemphasisFilter.idealFilterResponse.frequency");
            if (deemphasisFilter.idealFilterResponse.amplitudeDB == null)
                throw new ArgumentNullException("deemphasisFilter.idealFilterResponse.amplitudeDB");
            if (deemphasisFilter.idealFilterResponse.phaseDelay == null)
                throw new ArgumentNullException("deemphasisFilter.idealFilterResponse.phaseDelay");
            if (deemphasisFilter.idealFilterResponse.groupDelay == null)
                throw new ArgumentNullException("deemphasisFilter.idealFilterResponse.groupDelay");
            if (deemphasisFilter.actualFilterResponse.frequency == null)
                throw new ArgumentNullException("deemphasisFilter.actualFilterResponse.frequency");
            if (deemphasisFilter.actualFilterResponse.amplitudeDB == null)
                throw new ArgumentNullException("deemphasisFilter.actualFilterResponse.amplitudeDB");
            if (deemphasisFilter.actualFilterResponse.phaseDelay == null)
                throw new ArgumentNullException("deemphasisFilter.actualFilterResponse.phaseDelay");
            if (deemphasisFilter.actualFilterResponse.groupDelay == null)
                throw new ArgumentNullException("deemphasisFilter.actualFilterResponse.groupDelay");

            // Allocate memory for the deviation struct
            Deviation deviation = new Deviation();

            // Calculate the length of the deviation vectors
            length = deemphasisFilter.actualFilterResponse.frequency.Length;

            // Copy the frequency vector from the actual filter response
            deviation.frequency = (double[])deemphasisFilter.actualFilterResponse.frequency.Clone();

            // Create the deviation vectors
            deviation.amplitudeDB = new double[length];
            deviation.phaseDelay = new double[length];
            deviation.groupDelay = new double[length];

            // Calculate the position of the DC component in the ideal filter
            // response vectors
            int DCIndex =
                (deemphasisFilter.idealFilterResponse.amplitudeDB.Length / 2) - 1;

            // Calculate the amplitude deviation
            for (int i = 0, j = DCIndex; i < length; i++, j++)
            {
                deviation.amplitudeDB[i] =
                    deemphasisFilter.actualFilterResponse.amplitudeDB[i] -
                    deemphasisFilter.idealFilterResponse.amplitudeDB[j];
            }

            // Record the minimum and maximum amplitude deviations
            deviation.amplitudeDeviationMin = deviation.amplitudeDB.Min();
            deviation.amplitudeDeviationMax = deviation.amplitudeDB.Max();

            // Calculate the phase delay deviation
            // First calculate the offset at f = 0
            double offset =
                deemphasisFilter.actualFilterResponse.phaseDelay[0] -
                deemphasisFilter.idealFilterResponse.phaseDelay[DCIndex];

            // Then calculate the deviation for each element
            for (int i = 0, j = DCIndex; i < length; i++, j++)
            {
                deviation.phaseDelay[i] =
                    deemphasisFilter.actualFilterResponse.phaseDelay[i] -
                    deemphasisFilter.idealFilterResponse.phaseDelay[j] -
                    offset;
            }

            // Record the minimum and maximum phase delay deviations
            deviation.phaseDelayDeviationMin = deviation.phaseDelay.Min();
            deviation.phaseDelayDeviationMax = deviation.phaseDelay.Max();

            // Calculate the group delay deviation
            // First calculate the offset at f = 0
            offset =
                deemphasisFilter.actualFilterResponse.groupDelay[0] -
                deemphasisFilter.idealFilterResponse.groupDelay[DCIndex];

            // Then calculate the deviation for each element
            for (int i = 0, j = DCIndex; i < length; i++, j++)
            {
                deviation.groupDelay[i] =
                    deemphasisFilter.actualFilterResponse.groupDelay[i] -
                    deemphasisFilter.idealFilterResponse.groupDelay[j] -
                    offset;
            }

            // Record the minimum and maximum group delay deviations
            deviation.groupDelayDeviationMin = deviation.groupDelay.Min();
            deviation.groupDelayDeviationMax = deviation.groupDelay.Max();

            // Return a pointer to the newly calculated deviation structure
            return deviation;
        }


    }
}
