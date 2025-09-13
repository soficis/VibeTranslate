using System;
using System.Collections.Generic;
using System.Linq;

namespace TranslationFiestaCSharp
{
    /// <summary>
    /// Provides functionality for generating random numbers and selecting random elements.
    /// </summary>
    public static class RandomizationEngine
    {
        private static readonly Random _random = new Random();

        /// <summary>
        /// Returns a non-negative random integer.
        /// </summary>
        /// <returns>A 32-bit signed integer that is greater than or equal to 0 and less than MaxValue.</returns>
        public static int GetRandomInt()
        {
            return _random.Next();
        }

        /// <summary>
        /// Returns a non-negative random integer that is less than the specified maximum.
        /// </summary>
        /// <param name="max">The exclusive upper bound of the random number to be generated.</param>
        /// <returns>A 32-bit signed integer that is greater than or equal to 0, and less than max.</returns>
        public static int GetRandomInt(int max)
        {
            return _random.Next(max);
        }

        /// <summary>
        /// Returns a random integer that is within a specified range.
        /// </summary>
        /// <param name="min">The inclusive lower bound of the random number returned.</param>
        /// <param name="max">The exclusive upper bound of the random number returned.</param>
        /// <returns>A 32-bit signed integer greater than or equal to min and less than max.</returns>
        public static int GetRandomInt(int min, int max)
        {
            return _random.Next(min, max);
        }

        /// <summary>
        /// Returns a random floating-point number that is greater than or equal to 0.0, and less than 1.0.
        /// </summary>
        /// <returns>A double-precision floating point number that is greater than or equal to 0.0, and less than 1.0.</returns>
        public static double GetRandomDouble()
        {
            return _random.NextDouble();
        }

        /// <summary>
        /// Selects a random element from a list.
        /// </summary>
        /// <typeparam name="T">The type of the elements of the list.</typeparam>
        /// <param name="list">The list to select an element from.</param>
        /// <returns>A random element from the list.</returns>
        public static T GetRandomElement<T>(IList<T> list)
        {
            if (list == null || !list.Any())
            {
                throw new ArgumentException("List cannot be null or empty.", nameof(list));
            }
            return list[GetRandomInt(list.Count)];
        }
    }
}