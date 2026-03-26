import SwiftUI

struct BudgetBreakdownView: View {
    let budget: BudgetState
    var onOverride: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("SPEND BREAKDOWN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if budget.isOverrideActive {
                    Text("2x OVERRIDE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Button { onDismiss?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Per-agent rows
            if budget.spendByAgent.isEmpty {
                Text("No runs today")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(budget.spendByAgent) { agent in
                    HStack(spacing: 6) {
                        Text(agent.displayName)
                            .font(.system(size: 10))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("$\(String(format: "%.0f", agent.totalSpend))")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 35, alignment: .trailing)

                        Text("\(agent.runCount)x")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(width: 25, alignment: .trailing)

                        // Proportion bar
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(agentColor(agent.name))
                                .frame(width: max(2, geo.size.width * (budget.totalSpent > 0 ? agent.totalSpend / budget.totalSpent : 0)), height: 4)
                        }
                        .frame(width: 60, height: 4)
                    }
                }
            }

            // Total line
            HStack(spacing: 6) {
                Text("Total")
                    .font(.system(size: 10, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("$\(String(format: "%.0f", budget.totalSpent))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .frame(width: 35, alignment: .trailing)

                Text("/ $\(String(format: "%.0f", budget.dailyCap))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
            }
            .padding(.top, 2)

            // Override button — only when exhausted and no active override
            if budget.isExhausted && !budget.isOverrideActive {
                Divider()
                if showConfirm {
                    HStack {
                        Text("Double to $\(String(format: "%.0f", budget.dailyCap * 2)) for today?")
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        Button("Yes") {
                            onOverride?()
                            showConfirm = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.mini)

                        Button("No") {
                            showConfirm = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                } else {
                    Button {
                        showConfirm = true
                    } label: {
                        Label("Override Budget (2x for today)", systemImage: "arrow.up.circle")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func agentColor(_ name: String) -> Color {
        switch AgentDefinition(rawValue: name) {
        case .slackMonitor:      return .purple
        case .confluenceMonitor: return .blue
        case .meetingMonitor:    return .green
        case .orchestrator:      return .orange
        case .contextDigest:     return .cyan
        case .selfImprovement:   return .pink
        case .cleanup:           return .gray
        case .none:              return .secondary
        }
    }
}
