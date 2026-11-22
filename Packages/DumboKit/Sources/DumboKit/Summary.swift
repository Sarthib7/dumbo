import Foundation

public struct DaySummary: Identifiable, Equatable, Sendable {
    public var date: Date
    public var sessions: [Session]
    public var screenMinutes: Int
    public var longestMinutes: Int
    public var averageEnergy: Double
    public var promptsShown: Int
    public var promptsDone: Int
    public var glasses: Int
    public var breaths: Int
    public var eyeBreaks: Int
    /// One row per screen session, newest first.
    public var breakdown: [SessionStats] = []

    public var id: Date { date }
}

/// What happened during one screen session.
public struct SessionStats: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var minutes: Int
    public var minEnergy: Double
    public var glasses: Int
    public var breaths: Int
    public var eyeBreaks: Int
}

public struct WeekSummary: Equatable, Sendable {
    public static let heatmapBuckets = ["6a", "9a", "12p", "3p", "6p", "9p"]

    public var days: [DaySummary]
    public var dailyAverage: Int
    public var previousAverage: Int
    public var promptsShown: Int
    public var promptsDone: Int
    public var glasses: Int
    public var daysUnderGoal: Int
    public var longest: Session?
    /// Rows follow `days`; columns follow `heatmapBuckets`. Values are minutes.
    public var heatmap: [[Int]]
    public var insight: String

    public var changePercent: Int? {
        guard previousAverage > 0 else { return nil }
        return Int(((Double(dailyAverage) - Double(previousAverage)) / Double(previousAverage) * 100).rounded())
    }

    public var breakRate: Double {
        promptsShown == 0 ? 0 : Double(promptsDone) / Double(promptsShown)
    }
}

public enum Summarizer {
    public static func day(_ date: Date, data: DumboData, calendar: Calendar = .current) -> DaySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let range = start..<end
        let sessions = data.sessions.filter { minutes(of: $0, in: range) > 0 || range.contains($0.start) }
        let prompts = data.prompts.filter { range.contains($0.date) }
        let done = prompts.filter { $0.outcome == .done }
        let perSession = sessions.map { minutes(of: $0, in: range) }
        let total = perSession.reduce(0, +)
        let avg = sessions.isEmpty ? 100 : sessions.reduce(0) { $0 + $1.minEnergy } / Double(sessions.count)
        return DaySummary(
            date: start,
            sessions: sessions,
            screenMinutes: total,
            longestMinutes: perSession.max() ?? 0,
            averageEnergy: avg,
            promptsShown: prompts.filter { $0.kind != .empty }.count,
            promptsDone: done.filter { $0.kind != .empty }.count,
            glasses: data.water.filter { range.contains($0) }.count,
            breaths: done.filter { $0.kind == .breathe }.count,
            eyeBreaks: done.filter { $0.kind == .eyes }.count,
            breakdown: sessions.reversed().map { s in
                let span = s.start...s.lastActivity.addingTimeInterval(DumboEngine.newSessionGap)
                let doneHere = done.filter { span.contains($0.date) }
                return SessionStats(id: s.id, start: s.start, minutes: minutes(of: s, in: range), minEnergy: s.minEnergy,
                                    glasses: data.water.filter { span.contains($0) }.count,
                                    breaths: doneHere.filter { $0.kind == .breathe }.count,
                                    eyeBreaks: doneHere.filter { $0.kind == .eyes }.count)
            }
        )
    }

    public static func week(endingOn date: Date, data: DumboData, calendar: Calendar = .current) -> WeekSummary {
        let today = calendar.startOfDay(for: date)
        let days = (0..<7).reversed().map { day(calendar.date(byAdding: .day, value: -$0, to: today)!, data: data, calendar: calendar) }
        let previous = (7..<14).map { day(calendar.date(byAdding: .day, value: -$0, to: today)!, data: data, calendar: calendar) }
        let total = days.reduce(0) { $0 + $1.screenMinutes }
        let prevTotal = previous.reduce(0) { $0 + $1.screenMinutes }
        let goal = data.settings.dailyGoalMinutes

        var heat = Array(repeating: Array(repeating: 0, count: WeekSummary.heatmapBuckets.count), count: 7)
        for (row, d) in days.enumerated() {
            for s in d.sessions { heat[row][bucket(for: s.start, calendar: calendar)] += s.minutes }
        }

        return WeekSummary(
            days: days,
            dailyAverage: total / 7,
            previousAverage: prevTotal / 7,
            promptsShown: days.reduce(0) { $0 + $1.promptsShown },
            promptsDone: days.reduce(0) { $0 + $1.promptsDone },
            glasses: days.reduce(0) { $0 + $1.glasses },
            daysUnderGoal: days.filter { $0.screenMinutes <= goal && $0.screenMinutes > 0 }.count,
            longest: days.flatMap(\.sessions).max { $0.minutes < $1.minutes },
            heatmap: heat,
            insight: insight(days: days, heat: heat, calendar: calendar)
        )
    }

    /// Minutes of `session` that fall inside `range`, spread evenly over the session's span.
    static func minutes(of session: Session, in range: Range<Date>) -> Int {
        let span = session.lastActivity.timeIntervalSince(session.start)
        guard span > 0 else { return range.contains(session.start) ? session.minutes : 0 }
        let overlap = min(session.lastActivity, range.upperBound).timeIntervalSince(max(session.start, range.lowerBound))
        return overlap <= 0 ? 0 : Int((Double(session.minutes) * overlap / span).rounded())
    }

    static func bucket(for date: Date, calendar: Calendar) -> Int {
        let h = calendar.component(.hour, from: date)
        if h < 6 { return heatmapBucketsLast }
        return min(heatmapBucketsLast, (h - 6) / 3)
    }

    private static var heatmapBucketsLast: Int { WeekSummary.heatmapBuckets.count - 1 }

    static func insight(days: [DaySummary], heat: [[Int]], calendar: Calendar) -> String {
        var best = (row: 0, col: 0, value: 0)
        for (r, row) in heat.enumerated() {
            for (c, v) in row.enumerated() where v > best.value { best = (r, c, v) }
        }
        guard best.value > 0 else { return "Quiet week. Your eyes say thanks." }
        let parts = ["mornings", "late mornings", "afternoons", "late afternoons", "evenings", "nights"]
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "EEEE"
        return "\(f.string(from: days[best.row].date)) \(parts[best.col]) are your scroll zone."
    }
}
