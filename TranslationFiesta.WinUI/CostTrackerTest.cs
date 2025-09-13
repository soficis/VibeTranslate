using System;

namespace TranslationFiesta.WinUI
{
    /// <summary>
    /// Simple test class for CostTracker functionality
    /// </summary>
    public static class CostTrackerTest
    {
        public static void RunTests()
        {
            Console.WriteLine("Running CostTracker tests...");

            var costTracker = new CostTracker();

            // Test cost calculation
            var cost1 = costTracker.CalculateCost(1000000); // 1M characters = $20
            Console.WriteLine($"Cost for 1M chars: ${cost1:F6} (expected: $20.000000)");

            var cost2 = costTracker.CalculateCost(500000); // 500K characters = $10
            Console.WriteLine($"Cost for 500K chars: ${cost2:F6} (expected: $10.000000)");

            var cost3 = costTracker.CalculateCost(100); // 100 characters = $0.002
            Console.WriteLine($"Cost for 100 chars: ${cost3:F6} (expected: $0.002000)");

            // Test recording translation
            Console.WriteLine("\nTesting translation recording...");
            costTracker.RecordTranslation(1000, "en", "ja");
            costTracker.RecordTranslation(2000, "en", "es");

            var stats = costTracker.GetCurrentMonthStats();
            Console.WriteLine($"Monthly stats - Characters: {stats.TotalCharacters}, Cost: ${stats.TotalCost:F6}, Translations: {stats.TranslationCount}");

            Console.WriteLine("CostTracker tests completed.");
        }
    }
}