import SwiftUI

struct AgentDetailView: View {
    let agent: AgentStatus
    let onOpenSkill: () -> Void
    let onOpenLog: () -> Void
    let onRun: () -> Void
    let onTogglePause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status bar
            HStack(spacing: 12) {
                Label(agent.statusLabel, systemImage: statusIcon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor)

                Text("$\(String(format: "%.0f", agent.definition.maxBudgetPerRun))/run")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let wm = agent.watermark {
                    if let found = wm.itemsFound, let written = wm.itemsWritten {
                        Text("\(found) found, \(written) written")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Error display
            if let error = agent.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 9))
                    Text(error)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .padding(6)
                .background(Color.red.opacity(0.08))
                .cornerRadius(4)
            }

            // Recent runs
            if !agent.recentRuns.isEmpty {
                Text("RECENT RUNS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)

                VStack(spacing: 2) {
                    ForEach(agent.recentRuns) { run in
                        HStack {
                            Text(run.timestampLabel)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 40, alignment: .leading)

                            Text(run.durationLabel)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)

                            runOutcomeBadge(run.outcome)

                            Spacer()
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button(action: onRun) {
                    Label("Run Now", systemImage: "play.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(agent.runState == .running)

                Button(action: onTogglePause) {
                    Label(
                        agent.runState == .paused ? "Resume" : "Pause",
                        systemImage: agent.runState == .paused ? "play.circle" : "pause.circle"
                    )
                    .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if agent.definition.skillFilePath != nil {
                    Button(action: onOpenSkill) {
                        Label("Skill", systemImage: "doc.text")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: onOpenLog) {
                    Label("Log", systemImage: "doc.plaintext")
                        .font(.system(size: 10))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 8)
        .padding(.top, 2)
    }

    private func runOutcomeBadge(_ outcome: AgentRun.Outcome) -> some View {
        Group {
            switch outcome {
            case .success:
                Label("OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error(let msg):
                Label(String(msg.prefix(30)), systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .unknown:
                Label("—", systemImage: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 10))
    }

    private var statusIcon: String {
        switch agent.runState {
        case .idle:          return "checkmark.circle"
        case .running:       return "arrow.triangle.2.circlepath"
        case .error:         return "xmark.circle"
        case .paused:        return "pause.circle"
        case .budgetPaused:  return "dollarsign.circle"
        case .unknown:       return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch agent.runState {
        case .idle:          return .green
        case .running:       return .blue
        case .error:         return .red
        case .paused:        return .orange
        case .budgetPaused:  return .orange
        case .unknown:       return .green
        }
    }
}
