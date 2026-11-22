import DumboKit
import Foundation

/// Deterministic two weeks of history for demos and screenshots.
enum SampleData {
    static func make(now: Date, settings: Settings, calendar: Calendar = .current) -> DumboData {
        var rng = SeededRNG(seed: 7)
        var d = DumboData()
        d.settings = settings
        d.settings.onboarded = true
        let hours = [7, 8, 9, 10, 12, 13, 15, 17, 19, 20, 21, 21, 22, 22, 23]
        let drain = 100 / settings.mode.drainMinutes

        for back in (0..<14).reversed() {
            let day = calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: now))!
            let heavier = back >= 7 ? 1.3 : 1.0
            let picks = (0..<Int.random(in: 6...9, using: &rng)).map { _ in hours.randomElement(using: &rng)! }.sorted()
            var cursor = day
            for h in picks {
                var start = day.addingTimeInterval(Double(h) * 3600 + Double(Int.random(in: 0...40, using: &rng)) * 60)
                if start < cursor { start = cursor.addingTimeInterval(12 * 60) }
                var minutes = Int(Double(Int.random(in: 5...38, using: &rng)) * heavier * (h >= 21 ? 1.6 : 1))
                if calendar.component(.weekday, from: day) == 4 && h >= 21 { minutes += 25 }
                let end = start.addingTimeInterval(Double(minutes) * 60)
                guard end < now.addingTimeInterval(-10 * 60) else { continue }

                var done = 0
                for (i, m) in stride(from: 10, through: minutes, by: 10).enumerated() {
                    let kind = PromptKind.rotation[i % PromptKind.rotation.count]
                    let ok = Int.random(in: 0..<100, using: &rng) < 72
                    let at = start.addingTimeInterval(Double(m) * 60)
                    d.prompts.append(PromptEvent(date: at, kind: kind, outcome: ok ? .done : .skipped))
                    if ok {
                        done += 1
                        if kind == .sip { d.water.append(at) }
                    }
                }
                var s = Session(start: start)
                s.lastActivity = end
                s.minutes = minutes
                s.energy = max(0, min(100, 100 - drain * Double(minutes) + 20 * Double(done)))
                s.minEnergy = max(0, min(s.energy, 100 - drain * Double(minutes) * 0.8))
                s.promptsShown = minutes / 10
                s.lastPromptMinute = (minutes / 10) * 10
                d.sessions.append(s)
                cursor = end
            }
            for _ in 0..<Int.random(in: 2...5, using: &rng) {
                let at = day.addingTimeInterval(Double(Int.random(in: 8 * 60...22 * 60, using: &rng)) * 60)
                if at < now { d.water.append(at) }
            }
        }
        d.water.sort()
        return d
    }
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
