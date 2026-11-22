import Foundation

/// Pure rules for sessions, energy and nudges. All mutations go through here.
public enum DumboEngine {
    /// Phone down at least this long starts a fresh session.
    public static let newSessionGap: TimeInterval = 5 * 60
    /// Energy given back by a finished break.
    public static let breakBoost: Double = 20
    /// An unanswered prompt collapses after this long.
    public static let promptTimeout: TimeInterval = 2 * 60
    /// Retention window for history.
    public static let historyDays = 35

    public static func currentSession(at date: Date, in data: DumboData) -> Session? {
        guard let last = data.sessions.last,
              date.timeIntervalSince(last.lastActivity) < newSessionGap + 60 else { return nil }
        return last
    }

    /// Records `minutes` of screen use ending at `date`. Returns a nudge if one is due.
    @discardableResult
    public static func recordUse(minutes: Int = 1, at date: Date, in data: inout DumboData) -> PromptKind? {
        guard minutes > 0 else { return nil }
        expirePrompt(at: date, in: &data)

        var session: Session
        if currentSession(at: date, in: data) != nil {
            session = data.sessions.removeLast()
        } else {
            session = Session(start: date.addingTimeInterval(-60 * Double(minutes)))
            if let p = data.activePrompt { finish(p, outcome: .skipped, in: &data) }
        }

        let drain = 100 / data.settings.mode.drainMinutes
        session.minutes += minutes
        session.energy = max(0, session.energy - drain * Double(minutes))
        session.minEnergy = min(session.minEnergy, session.energy)
        session.lastActivity = date

        var due: PromptKind?
        let every = max(1, data.settings.promptEveryMinutes)
        if data.activePrompt == nil, session.minutes - session.lastPromptMinute >= every {
            due = session.energy <= 0 ? .empty : PromptKind.rotation[session.promptsShown % PromptKind.rotation.count]
            session.lastPromptMinute = session.minutes
            session.promptsShown += 1
        }
        data.sessions.append(session)
        return due
    }

    @discardableResult
    public static func show(_ kind: PromptKind, at date: Date, in data: inout DumboData) -> ActivePrompt {
        if let p = data.activePrompt { finish(p, outcome: .skipped, in: &data) }
        let event = PromptEvent(date: date, kind: kind, outcome: .shown)
        data.prompts.append(event)
        let prompt = ActivePrompt(kind: kind, started: date,
                                  line: LineDeck.line(kind, tone: data.settings.tone),
                                  eventID: event.id)
        data.activePrompt = prompt
        return prompt
    }

    /// A break was finished, either from a prompt or started by the user.
    public static func complete(_ kind: PromptKind, at date: Date, in data: inout DumboData) {
        if let p = data.activePrompt, p.kind == kind {
            finish(p, outcome: .done, in: &data)
        } else {
            data.prompts.append(PromptEvent(date: date, kind: kind, outcome: .done))
        }
        if kind == .sip { data.water.append(date) }
        boost(at: date, in: &data)
    }

    public static func skip(at date: Date, in data: inout DumboData) {
        if let p = data.activePrompt { finish(p, outcome: .skipped, in: &data) }
    }

    /// "+ glass" from anywhere. Answers a pending sip prompt.
    public static func logGlass(at date: Date, in data: inout DumboData) {
        if data.activePrompt?.kind == .sip {
            complete(.sip, at: date, in: &data)
        } else {
            data.water.append(date)
        }
    }

    public static func expirePrompt(at date: Date, in data: inout DumboData) {
        if let p = data.activePrompt, date.timeIntervalSince(p.started) > promptTimeout {
            data.activePrompt = nil
        }
    }

    public static func trim(at date: Date, in data: inout DumboData, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -historyDays, to: calendar.startOfDay(for: date)) else { return }
        data.sessions.removeAll { $0.lastActivity < cutoff }
        data.prompts.removeAll { $0.date < cutoff }
        data.water.removeAll { $0 < cutoff }
    }

    /// Converts a cumulative Screen Time threshold (minutes today) into newly used minutes.
    public static func minutesSinceCursor(threshold: Int, at date: Date, in data: inout DumboData, calendar: Calendar = .current) -> Int {
        let day = calendar.startOfDay(for: date)
        let previous = (data.cursor?.day == day) ? data.cursor!.minute : 0
        data.cursor = MonitorCursor(day: day, minute: max(previous, threshold))
        return max(0, threshold - previous)
    }

    private static func boost(at date: Date, in data: inout DumboData) {
        guard currentSession(at: date, in: data) != nil else { return }
        var s = data.sessions.removeLast()
        s.energy = min(100, s.energy + breakBoost)
        data.sessions.append(s)
    }

    private static func finish(_ prompt: ActivePrompt, outcome: PromptEvent.Outcome, in data: inout DumboData) {
        if let i = data.prompts.lastIndex(where: { $0.id == prompt.eventID }) {
            data.prompts[i].outcome = outcome
        }
        data.activePrompt = nil
    }
}
