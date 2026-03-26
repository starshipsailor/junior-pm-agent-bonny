import Foundation

struct BudgetState {
    var date: String = ""
    var totalSpent: Double = 0
    var dailyCap: Double = 50
    var baseCap: Double = 50
    var isOverrideActive: Bool = false
    var runs: [BudgetRun] = []

    var remaining: Double { max(0, dailyCap - totalSpent) }
    var percentUsed: Double { dailyCap > 0 ? totalSpent / dailyCap : 0 }
    var isExhausted: Bool { totalSpent >= dailyCap }

    var spendByAgent: [AgentSpend] {
        Dictionary(grouping: runs, by: \.monitor)
            .map { AgentSpend(name: $0.key, totalSpend: $0.value.reduce(0) { $0 + $1.maxBudget }, runCount: $0.value.count) }
            .sorted { $0.totalSpend > $1.totalSpend }
    }

    static let empty = BudgetState()
}

struct AgentSpend: Identifiable {
    let name: String
    let totalSpend: Double
    let runCount: Int
    var id: String { name }

    var displayName: String {
        AgentDefinition(rawValue: name)?.displayName ?? name
    }
}

struct BudgetRun: Codable {
    let monitor: String
    let timestamp: String
    let maxBudget: Double

    enum CodingKeys: String, CodingKey {
        case monitor
        case timestamp
        case maxBudget = "max_budget"
    }
}

struct DailySpendJSON: Codable {
    let date: String
    let runs: [BudgetRun]
    let totalUsd: Double

    enum CodingKeys: String, CodingKey {
        case date
        case runs
        case totalUsd = "total_usd"
    }
}

struct BudgetOverrideJSON: Codable {
    let date: String
    let cap: Double
}

struct InboxCounts: Equatable {
    var slack: Int = 0
    var confluence: Int = 0
    var meetings: Int = 0
    var total: Int { slack + confluence + meetings }

    static let zero = InboxCounts()
}
