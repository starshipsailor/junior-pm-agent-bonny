import SwiftUI

struct BudgetGaugeView: View {
    let budget: BudgetState
    var onToggleBreakdown: (() -> Void)?

    var body: some View {
        Button {
            onToggleBreakdown?()
        } label: {
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * budget.percentUsed)), height: 6)
                    }
                }
                .frame(width: 50, height: 6)

                Text("$\(String(format: "%.0f", budget.totalSpent))/$\(String(format: "%.0f", budget.dailyCap))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(budget.isExhausted ? .red : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Click for spend breakdown")
    }

    private var barColor: Color {
        if budget.percentUsed >= 1.0 { return .red }
        if budget.percentUsed >= 0.8 { return .orange }
        if budget.percentUsed >= 0.6 { return .yellow }
        return .green
    }
}
