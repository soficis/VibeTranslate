import Foundation

/// Cost tracking entry for individual translations
public struct CostEntry: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let characterCount: Int
    public let costUSD: Double
    public let sourceLanguage: Language
    public let targetLanguage: Language
    public let implementation: String
    public let apiProvider: APIProvider
    
    public init(
        characterCount: Int,
        costUSD: Double,
        sourceLanguage: Language,
        targetLanguage: Language,
        implementation: String = "swift",
        apiProvider: APIProvider,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.characterCount = characterCount
        self.costUSD = costUSD
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.implementation = implementation
        self.apiProvider = apiProvider
    }
}

/// Monthly budget configuration and tracking
public struct Budget: Equatable, Codable, Sendable {
    public var monthlyLimitUSD: Double
    public var currentMonthUsageUSD: Double
    public var alertThresholdPercent: Double
    public var lastResetTimestamp: Date
    public var alertsEnabled: Bool
    
    public init(
        monthlyLimitUSD: Double = 50.0,
        alertThresholdPercent: Double = 80.0,
        alertsEnabled: Bool = true
    ) {
        self.monthlyLimitUSD = monthlyLimitUSD
        self.currentMonthUsageUSD = 0.0
        self.alertThresholdPercent = alertThresholdPercent
        self.lastResetTimestamp = Date()
        self.alertsEnabled = alertsEnabled
    }
    
    public var remainingBudgetUSD: Double {
        return max(0, monthlyLimitUSD - currentMonthUsageUSD)
    }
    
    public var usagePercentage: Double {
        guard monthlyLimitUSD > 0 else { return 0 }
        return (currentMonthUsageUSD / monthlyLimitUSD) * 100.0
    }
    
    public var isOverBudget: Bool {
        return currentMonthUsageUSD > monthlyLimitUSD
    }
    
    public var shouldAlert: Bool {
        return alertsEnabled && usagePercentage >= alertThresholdPercent
    }
    
    public var alertThresholdUSD: Double {
        return monthlyLimitUSD * (alertThresholdPercent / 100.0)
    }
    
    public mutating func resetIfNewMonth() {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let lastResetMonth = calendar.component(.month, from: lastResetTimestamp)
        let currentYear = calendar.component(.year, from: Date())
        let lastResetYear = calendar.component(.year, from: lastResetTimestamp)
        
        if currentYear > lastResetYear || (currentYear == lastResetYear && currentMonth > lastResetMonth) {
            currentMonthUsageUSD = 0.0
            lastResetTimestamp = Date()
        }
    }
    
    public mutating func addUsage(_ cost: Double) {
        resetIfNewMonth()
        currentMonthUsageUSD += cost
    }
}

/// Budget status information
public struct BudgetStatus: Equatable, Codable {
    public let currentMonthUsageUSD: Double
    public let monthlyLimitUSD: Double
    public let remainingBudgetUSD: Double
    public let usagePercentage: Double
    public let isOverBudget: Bool
    public let shouldAlert: Bool
    public let alertThresholdPercent: Double
    public let daysRemainingInMonth: Int
    
    public init(from budget: Budget) {
        self.currentMonthUsageUSD = budget.currentMonthUsageUSD
        self.monthlyLimitUSD = budget.monthlyLimitUSD
        self.remainingBudgetUSD = budget.remainingBudgetUSD
        self.usagePercentage = budget.usagePercentage
        self.isOverBudget = budget.isOverBudget
        self.shouldAlert = budget.shouldAlert
        self.alertThresholdPercent = budget.alertThresholdPercent
        
        // Calculate days remaining in current month
        let calendar = Calendar.current
        let currentDate = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
        self.daysRemainingInMonth = calendar.dateComponents([.day], from: currentDate, to: endOfMonth).day ?? 0
    }
}

/// Cost report for a specific time period
public struct CostReport: Equatable, Codable {
    public let startDate: Date
    public let endDate: Date
    public let totalCostUSD: Double
    public let totalCharacters: Int
    public let entryCount: Int
    public let entries: [CostEntry]
    public let breakdown: CostBreakdown
    
    public init(entries: [CostEntry], startDate: Date, endDate: Date) {
        self.entries = entries
        self.startDate = startDate
        self.endDate = endDate
        self.totalCostUSD = entries.map(\.costUSD).reduce(0, +)
        self.totalCharacters = entries.map(\.characterCount).reduce(0, +)
        self.entryCount = entries.count
        self.breakdown = CostBreakdown(entries: entries)
    }
    
    public var averageCostPerEntry: Double {
        guard entryCount > 0 else { return 0 }
        return totalCostUSD / Double(entryCount)
    }
    
    public var averageCharactersPerEntry: Double {
        guard entryCount > 0 else { return 0 }
        return Double(totalCharacters) / Double(entryCount)
    }
}

/// Breakdown of costs by various dimensions
public struct CostBreakdown: Equatable, Codable {
    public let byApiProvider: [APIProvider: Double]
    public let byLanguagePair: [String: Double]
    public let byImplementation: [String: Double]
    public let byDay: [String: Double]
    
    public init(entries: [CostEntry]) {
        var providerCosts: [APIProvider: Double] = [:]
        var languagePairCosts: [String: Double] = [:]
        var implementationCosts: [String: Double] = [:]
        var dailyCosts: [String: Double] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for entry in entries {
            // By API provider
            providerCosts[entry.apiProvider, default: 0] += entry.costUSD
            
            // By language pair
            let languagePair = "\(entry.sourceLanguage.rawValue)->\(entry.targetLanguage.rawValue)"
            languagePairCosts[languagePair, default: 0] += entry.costUSD
            
            // By implementation
            implementationCosts[entry.implementation, default: 0] += entry.costUSD
            
            // By day
            let dayKey = dateFormatter.string(from: entry.timestamp)
            dailyCosts[dayKey, default: 0] += entry.costUSD
        }
        
        self.byApiProvider = providerCosts
        self.byLanguagePair = languagePairCosts
        self.byImplementation = implementationCosts
        self.byDay = dailyCosts
    }
}

/// Alert types for budget notifications
public enum BudgetAlert: Equatable, Codable {
    case thresholdReached(percentage: Double, amount: Double)
    case budgetExceeded(amount: Double, overage: Double)
    case monthlyReset(newMonth: String)
    
    public var title: String {
        switch self {
        case .thresholdReached(let percentage, _):
            return "Budget Alert: \(Int(percentage))% Used"
        case .budgetExceeded(_, _):
            return "Budget Exceeded"
        case .monthlyReset(let month):
            return "Budget Reset - \(month)"
        }
    }
    
    public var message: String {
        switch self {
        case .thresholdReached(let percentage, let amount):
            return "You have used \(Int(percentage))% of your monthly budget ($\(String(format: "%.2f", amount)))."
        case .budgetExceeded(let amount, let overage):
            return "Your monthly budget has been exceeded. Current usage: $\(String(format: "%.2f", amount)) (over by $\(String(format: "%.2f", overage)))."
        case .monthlyReset(let month):
            return "Your budget has been reset for \(month). Current usage: $0.00."
        }
    }
}