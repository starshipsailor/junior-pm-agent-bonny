import SwiftUI

struct MenuBarView: View {
    @Bindable var state: AppState
    @State private var selectedAgent: AgentDefinition?
    @State private var showBudgetBreakdown = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Budget breakdown (expandable)
            if showBudgetBreakdown {
                Divider()
                BudgetBreakdownView(
                    budget: state.budget,
                    onOverride: { state.overrideBudget() },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showBudgetBreakdown = false
                        }
                    }
                )
            }

            Divider()

            // Budget + Inbox
            statusBar

            Divider()

            // Agent list
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(state.agents) { agent in
                        AgentRowView(
                            agent: agent,
                            isExpanded: selectedAgent == agent.definition,
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedAgent = selectedAgent == agent.definition ? nil : agent.definition
                                }
                            },
                            onRun: { state.triggerRun(agent.definition) },
                            onTogglePause: { state.togglePause(agent.definition) },
                            onOpenSkill: { state.openSkill(agent.definition) },
                            onOpenLog: { state.openLog(agent.definition) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Auth status
            authSection

            Divider()

            // Footer
            footerSection
        }
        .background(.background)
        .onAppear {
            state.startAutoRefresh()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("BONNY MONITOR")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            BudgetGaugeView(budget: state.budget, onToggleBreakdown: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showBudgetBreakdown.toggle()
                }
            })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            Label("Inbox", systemImage: "tray")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            inboxBadge("S", count: state.inboxCounts.slack, color: .purple)
            inboxBadge("C", count: state.inboxCounts.confluence, color: .blue)
            inboxBadge("M", count: state.inboxCounts.meetings, color: .green)

            Spacer()

            if state.inboxCounts.total > 0 {
                Text("\(state.inboxCounts.total) pending")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func inboxBadge(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 10, weight: count > 0 ? .bold : .regular, design: .monospaced))
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        HStack(spacing: 10) {
            Text("AUTH")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            authChip("Slack", plugin: "slack")
            authChip("Notion", plugin: "notion")
            authChip("Atlassian", plugin: "atlassian")

            Spacer()

            Button {
                state.checkAllAuth()
            } label: {
                if state.isCheckingAuth {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Label("Check", systemImage: "checkmark.shield")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .disabled(state.isCheckingAuth)
            .help("Run auth probes for all plugins")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func authChip(_ name: String, plugin: String) -> some View {
        let status = state.authStatus[plugin] ?? .unknown

        return Button {
            if status == .failed || status == .unknown {
                state.reAuth(plugin: plugin)
            } else {
                state.checkAuth(plugin: plugin)
            }
        } label: {
            HStack(spacing: 3) {
                Group {
                    switch status {
                    case .ok:
                        Circle().fill(Color.green)
                    case .failed:
                        Circle().fill(Color.red)
                    case .checking:
                        Circle().fill(Color.orange)
                    case .unknown:
                        Circle().fill(Color.gray)
                    }
                }
                .frame(width: 6, height: 6)

                Text(name)
                    .font(.system(size: 10))
                    .foregroundColor(status == .failed ? .red : .primary)
            }
        }
        .buttonStyle(.plain)
        .help(authHelp(name: name, status: status))
    }

    private func authHelp(name: String, status: AppState.AuthState) -> String {
        switch status {
        case .ok:       return "\(name): Authenticated — click to re-check"
        case .failed:   return "\(name): Auth expired — click to re-auth"
        case .checking: return "\(name): Checking..."
        case .unknown:  return "\(name): Not checked — click to re-auth or use Check button"
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button {
                state.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Button {
                state.processRunner.openProjectInFinder()
            } label: {
                Label("Open Project", systemImage: "folder")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Text(lastRefreshLabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var lastRefreshLabel: String {
        if state.lastRefresh == .distantPast { return "..." }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: state.lastRefresh)
    }
}
