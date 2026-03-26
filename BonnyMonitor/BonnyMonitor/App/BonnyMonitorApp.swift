import SwiftUI

@main
struct BonnyMonitorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: appState)
                .frame(width: 420, height: 620)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: menuBarIcon)
                if appState.inboxCounts.total > 0 {
                    Text("\(appState.inboxCounts.total)")
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    var menuBarIcon: String {
        if appState.agents.contains(where: { $0.runState == .error }) {
            return "exclamationmark.circle.fill"
        } else if appState.agents.contains(where: { $0.runState == .running }) {
            return "circle.dotted.circle"
        } else {
            return "b.circle.fill"
        }
    }
}
