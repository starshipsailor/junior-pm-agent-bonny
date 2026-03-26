import Foundation

enum AgentDefinition: String, CaseIterable, Identifiable {
    case slackMonitor      = "slack-monitor"
    case confluenceMonitor = "confluence-monitor"
    case meetingMonitor    = "meeting-monitor"
    case orchestrator      = "orchestrator"
    case contextDigest     = "context-digest"
    case selfImprovement   = "self-improvement"
    case cleanup           = "cleanup"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slackMonitor:      return "Slack Monitor"
        case .confluenceMonitor: return "Confluence Monitor"
        case .meetingMonitor:    return "Meeting Monitor"
        case .orchestrator:      return "Orchestrator"
        case .contextDigest:     return "Context Digest"
        case .selfImprovement:   return "Self-Improvement"
        case .cleanup:           return "Cleanup"
        }
    }

    var icon: String {
        switch self {
        case .slackMonitor:      return "number.square"
        case .confluenceMonitor: return "doc.text.magnifyingglass"
        case .meetingMonitor:    return "person.3"
        case .orchestrator:      return "gearshape.2"
        case .contextDigest:     return "doc.plaintext"
        case .selfImprovement:   return "brain"
        case .cleanup:           return "trash"
        }
    }

    var launchdLabel: String {
        switch self {
        case .orchestrator: return "com.bonny.pm-agent"
        default:            return "com.bonny.\(rawValue)"
        }
    }

    var scriptPath: String {
        switch self {
        case .slackMonitor:      return "scripts/monitor-slack.sh"
        case .confluenceMonitor: return "scripts/monitor-confluence.sh"
        case .meetingMonitor:    return "scripts/monitor-meetings.sh"
        case .orchestrator:      return "scripts/bonny-run.sh"
        case .contextDigest:     return "scripts/generate-context-digest.sh"
        case .selfImprovement:   return "scripts/self-improvement.sh"
        case .cleanup:           return "scripts/cleanup-archives.sh"
        }
    }

    var plistFilename: String {
        "\(launchdLabel).plist"
    }

    var watermarkFile: String? {
        switch self {
        case .slackMonitor:      return "state/slack-monitor-last-run.json"
        case .confluenceMonitor: return "state/confluence-monitor-last-run.json"
        case .meetingMonitor:    return "state/meeting-monitor-last-run.json"
        default:                 return nil
        }
    }

    var lockFile: String {
        switch self {
        case .orchestrator: return "state/bonny.lock"
        case .slackMonitor: return "state/slack-monitor.lock"
        case .confluenceMonitor: return "state/confluence-monitor.lock"
        case .meetingMonitor: return "state/meeting-monitor.lock"
        case .contextDigest: return "state/context-digest.lock"
        case .selfImprovement: return "state/self-improvement.lock"
        case .cleanup: return "state/cleanup.lock"
        }
    }

    /// Log file prefix in the logs/ directory
    var logPrefix: String {
        switch self {
        case .orchestrator: return ""  // orchestrator logs: YYYY-MM-DD_HHMMSS.log
        default:            return "\(rawValue)-"
        }
    }

    var skillFilePath: String? {
        switch self {
        case .slackMonitor:      return ".claude/commands/skills/slack-monitor-skill.md"
        case .confluenceMonitor: return ".claude/commands/skills/confluence-monitor-skill.md"
        case .meetingMonitor:    return ".claude/commands/skills/meeting-monitor-skill.md"
        case .orchestrator:      return "operating_guidelines.md"
        case .selfImprovement:   return nil
        case .contextDigest:     return nil
        case .cleanup:           return nil
        }
    }

    var inboxFile: String? {
        switch self {
        case .slackMonitor:      return "Mission_Control/inbox-slack.md"
        case .confluenceMonitor: return "Mission_Control/inbox-confluence.md"
        case .meetingMonitor:    return "Mission_Control/inbox-meetings.md"
        default:                 return nil
        }
    }

    var maxBudgetPerRun: Double {
        switch self {
        case .slackMonitor:      return 2.00
        case .confluenceMonitor: return 2.00
        case .meetingMonitor:    return 3.00
        case .orchestrator:      return 5.00
        case .contextDigest:     return 1.00
        case .selfImprovement:   return 3.00
        case .cleanup:           return 0.00
        }
    }

    /// Interval in seconds from plist (for interval-based agents)
    var scheduleIntervalSeconds: Int? {
        switch self {
        case .slackMonitor:      return 1800    // 30 min
        case .confluenceMonitor: return 7200    // 2 hours
        case .meetingMonitor:    return 3600    // 1 hour
        case .orchestrator:      return 3600    // 1 hour
        default:                 return nil
        }
    }

    /// Calendar schedule description (for calendar-based agents)
    var scheduleDescription: String {
        switch self {
        case .slackMonitor:      return "Every 30 min"
        case .confluenceMonitor: return "Every 2 hours"
        case .meetingMonitor:    return "Every 1 hour"
        case .orchestrator:      return "Every 1 hour"
        case .contextDigest:     return "Daily at 6:00 AM"
        case .selfImprovement:   return "Daily at 7:00 AM"
        case .cleanup:           return "Sundays at midnight"
        }
    }

    /// The stdout log file path in logs/ (launchd redirected output)
    var stdoutLogFile: String {
        switch self {
        case .slackMonitor:      return "logs/slack-monitor-stdout.log"
        case .confluenceMonitor: return "logs/confluence-monitor-stdout.log"
        case .meetingMonitor:    return "logs/meeting-monitor-stdout.log"
        case .orchestrator:      return "logs/launchd-stdout.log"
        case .contextDigest:     return "logs/context-digest-stdout.log"
        case .selfImprovement:   return "logs/self-improvement-stdout.log"
        case .cleanup:           return "logs/cleanup-stdout.log"
        }
    }
}
