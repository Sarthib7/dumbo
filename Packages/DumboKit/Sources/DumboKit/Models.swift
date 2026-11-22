import Foundation

public enum PromptKind: String, Codable, CaseIterable, Hashable, Sendable {
    case breathe, sip, eyes, empty

    /// Order used when rotating nudges during a session.
    public static let rotation: [PromptKind] = [.eyes, .breathe, .sip]
}

public enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
    case chill, normal, strict

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// Minutes of continuous screen-on time to drain from 100% to 0%.
    public var drainMinutes: Double {
        switch self {
        case .chill: 60
        case .normal: 45
        case .strict: 25
        }
    }
}

public enum Tone: String, Codable, CaseIterable, Identifiable, Sendable {
    case fun, flirty, calm

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct Settings: Codable, Equatable, Sendable {
    public var mode: Mode = .normal
    public var tone: Tone = .fun
    public var waterGoal: Int = 8
    public var dailyGoalMinutes: Int = 180
    public var promptEveryMinutes: Int = 10
    public var onboarded: Bool = false
    public var demo: Bool = false

    public init() {}
}

public struct Session: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var start: Date
    public var lastActivity: Date
    public var minutes: Int = 0
    public var energy: Double = 100
    public var minEnergy: Double = 100
    public var lastPromptMinute: Int = 0
    public var promptsShown: Int = 0

    public init(start: Date) {
        self.start = start
        self.lastActivity = start
    }
}

public struct PromptEvent: Codable, Identifiable, Equatable, Sendable {
    public enum Outcome: String, Codable, Sendable { case shown, done, skipped }

    public var id: UUID = UUID()
    public var date: Date
    public var kind: PromptKind
    public var outcome: Outcome

    public init(date: Date, kind: PromptKind, outcome: Outcome) {
        self.date = date
        self.kind = kind
        self.outcome = outcome
    }
}

public struct ActivePrompt: Codable, Equatable, Sendable {
    public var kind: PromptKind
    public var started: Date
    public var line: String
    public var eventID: UUID
}

/// Screen Time reports cumulative usage per day; this tracks the last threshold seen.
public struct MonitorCursor: Codable, Equatable, Sendable {
    public var day: Date
    public var minute: Int
}

public struct DumboData: Codable, Equatable, Sendable {
    public var settings = Settings()
    public var sessions: [Session] = []
    public var prompts: [PromptEvent] = []
    public var water: [Date] = []
    public var activePrompt: ActivePrompt?
    public var cursor: MonitorCursor?

    public init() {}
}

extension PromptKind: Identifiable {
    public var id: String { rawValue }
}
