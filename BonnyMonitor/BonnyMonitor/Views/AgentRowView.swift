import SwiftUI

struct AgentRowView: View {
    let agent: AgentStatus
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onRun: () -> Void
    let onTogglePause: () -> Void
    let onOpenSkill: () -> Void
    let onOpenLog: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                // Status indicator
                statusDot

                // Agent name + schedule
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.definition.displayName)
                        .font(.system(size: 12, weight: .medium))
                    Text(agent.definition.scheduleDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Last run
                VStack(alignment: .trailing, spacing: 1) {
                    Text(agent.lastRunRelative)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(agent.nextRunRelative)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                // Action buttons (visible on hover or always for running)
                if isHovering || agent.runState == .running {
                    actionButtons
                }

                // Expand chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }
            .onHover { isHovering = $0 }
            .background(isHovering ? Color.primary.opacity(0.04) : Color.clear)

            // Expanded detail
            if isExpanded {
                AgentDetailView(
                    agent: agent,
                    onOpenSkill: onOpenSkill,
                    onOpenLog: onOpenLog,
                    onRun: onRun,
                    onTogglePause: onTogglePause
                )
            }
        }
    }

    // MARK: - Status Dot

    private var statusDot: some View {
        Group {
            switch agent.runState {
            case .running:
                Image(systemName: "circle.dotted.circle")
                    .symbolEffect(.pulse, options: .repeating)
                    .foregroundStyle(.blue)
            case .budgetPaused:
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.orange)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.gray)
            default:
                Image(systemName: "circle.fill")
                    .foregroundStyle(statusColor)
            }
        }
        .font(.system(size: 8))
        .frame(width: 14)
    }

    private var statusColor: Color {
        switch agent.runState {
        case .idle:          return .green
        case .running:       return .blue
        case .error:         return .red
        case .paused:        return .gray
        case .budgetPaused:  return .orange
        case .unknown:       return .green
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 4) {
            if agent.runState != .running {
                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .help("Run now")
            }

            Button(action: onTogglePause) {
                Image(systemName: agent.runState == .paused ? "play.circle" : "pause.fill")
                    .font(.system(size: 9))
            }
            .buttonStyle(.plain)
            .foregroundStyle(agent.runState == .paused ? .blue : .orange)
            .help(agent.runState == .paused ? "Resume schedule" : "Pause schedule")
        }
    }
}
