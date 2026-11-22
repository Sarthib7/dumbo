import SwiftUI

/// Everything the Dynamic Island needs. Doubles as the Live Activity content state.
public struct IslandState: Codable, Hashable, Sendable {
    public static let breatheSeconds: TimeInterval = 30
    public static let eyesSeconds: TimeInterval = 20
    public static let breaths = 3
    public static let inhaleSeconds: TimeInterval = 4
    public static let exhaleSeconds: TimeInterval = 6

    /// The breathing exercise played inside the island (iOS 17+), so the app never has to open.
    /// The bars run on system timers, so they keep moving even if no further update arrives.
    public struct BreathStep: Codable, Hashable, Sendable {
        public var start: Date
        public var index: Int
        public var inhale: Bool { index % 2 == 0 }
        public var end: Date { start.addingTimeInterval(IslandState.breathTotal) }
        public func phase(_ i: Int) -> ClosedRange<Date> {
            let from = start.addingTimeInterval(IslandState.breathOffset(i))
            return from...from.addingTimeInterval(i % 2 == 0 ? IslandState.inhaleSeconds : IslandState.exhaleSeconds)
        }
    }

    public var sessionStart: Date
    public var energy: Double
    public var prompt: PromptKind?
    public var promptStarted: Date?
    public var line: String
    public var glasses: Int
    public var waterGoal: Int
    public var breath: BreathStep?
    /// Screen-on minutes today, for the expanded island.
    public var todayMinutes: Int?
    /// When energy hits 0 if the screen stays on, and how long a full drain takes; lets the bar drain live.
    public var energyEmpty: Date?
    public var drainSeconds: Double?

    public init(sessionStart: Date, energy: Double, prompt: PromptKind? = nil, promptStarted: Date? = nil,
                line: String = "", glasses: Int = 0, waterGoal: Int = 8, breath: BreathStep? = nil) {
        self.sessionStart = sessionStart
        self.energy = energy
        self.prompt = prompt
        self.promptStarted = promptStarted
        self.line = line
        self.glasses = glasses
        self.waterGoal = waterGoal
        self.breath = breath
    }

    public static var breathSteps: Int { breaths * 2 }

    public static var breathTotal: TimeInterval { Double(breaths) * (inhaleSeconds + exhaleSeconds) }

    /// Seconds from the start of the exercise to half-breath `step` (even = inhale, odd = exhale).
    public static func breathOffset(_ step: Int) -> TimeInterval {
        Double(step / 2) * (inhaleSeconds + exhaleSeconds) + (step % 2 == 1 ? inhaleSeconds : 0)
    }

    public func breathing(start: Date, step index: Int) -> IslandState {
        var s = self
        s.prompt = .breathe
        s.promptStarted = start
        s.breath = BreathStep(start: start, index: index)
        return s
    }

    public static func make(from data: DumboData, at date: Date, calendar: Calendar = .current) -> IslandState {
        let session = DumboEngine.currentSession(at: date, in: data)
        let today = calendar.startOfDay(for: date)
        let energy = session?.energy ?? 100
        let drain = data.settings.mode.drainMinutes * 60
        var state = IslandState(
            // Screen-on time, not wall-clock time since the session began; the island ticks it live from here.
            sessionStart: date.addingTimeInterval(-60 * Double(session?.minutes ?? 0)),
            energy: energy,
            prompt: data.activePrompt?.kind,
            promptStarted: data.activePrompt?.started,
            line: data.activePrompt?.line ?? "",
            glasses: data.water.filter { $0 >= today }.count,
            waterGoal: data.settings.waterGoal
        )
        state.todayMinutes = Summarizer.day(date, data: data, calendar: calendar).screenMinutes
        state.drainSeconds = drain
        state.energyEmpty = date.addingTimeInterval(energy / 100 * drain)
        return state
    }

    var promptStart: Date { promptStarted ?? sessionStart }

    /// The same state with the nudge removed, shown once a nudge goes stale.
    public var resting: IslandState {
        var s = self
        s.prompt = nil
        s.promptStarted = nil
        s.line = ""
        s.breath = nil
        return s
    }
    var tint: Color { Palette.color(for: prompt) }

    public var actionTitle: String? {
        if breath != nil { return nil }
        return switch prompt {
        case .breathe: "breathe"
        case .sip: "+ glass"
        case .eyes: "done"
        case .empty: "ok"
        case nil: nil
        }
    }
}

// MARK: - Pieces shared by the Live Activity, the lock screen and the in-app island.

public struct IslandGlyph: View {
    let state: IslandState
    let size: CGFloat

    public init(state: IslandState, size: CGFloat) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        MorphGlyph(shape: MorphShape(state.prompt), count: size < 30 ? 60 : 120,
                   energy: state.prompt == .empty ? 0 : state.energy,
                   level: max(0.3, Double(state.glasses) / Double(max(1, state.waterGoal))))
            .scaleEffect(state.breath.map { $0.inhale ? 1.25 : 0.55 } ?? 1)
            .animation(.easeInOut(duration: 2), value: state.breath?.inhale)
            .frame(width: size, height: size)
    }
}

public struct IslandValue: View {
    let state: IslandState
    let large: Bool

    public init(state: IslandState, large: Bool = false) {
        self.state = state
        self.large = large
    }

    public var body: some View {
        if let step = state.breath {
            Text(timerInterval: step.start...step.end)
                .font(.system(size: large ? 22 : 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.breath)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: large ? 90 : 52, alignment: .trailing)
        } else {
            text
        }
    }

    private var text: some View {
        Group {
            switch state.prompt {
            case nil:
                Text(state.sessionStart, style: .timer)
                    .foregroundStyle(Palette.ember)
            case .breathe:
                Text(timerInterval: state.promptStart...state.promptStart.addingTimeInterval(IslandState.breatheSeconds))
            case .eyes:
                Text(timerInterval: state.promptStart...state.promptStart.addingTimeInterval(IslandState.eyesSeconds))
            case .sip:
                Text("\(state.glasses)/\(state.waterGoal)")
            case .empty:
                Text("0%")
            }
        }
        .font(.system(size: large ? 22 : 14, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(state.tint)
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .frame(maxWidth: large ? 90 : 52, alignment: .trailing)
    }
}

public struct IslandLine: View {
    let state: IslandState
    public init(state: IslandState) { self.state = state }

    public var body: some View {
        if let step = state.breath {
            // One pair per breath: a bright bar fills on the inhale, a dim one on the exhale.
            HStack(spacing: 10) {
                ForEach(0..<IslandState.breaths, id: \.self) { i in
                    HStack(spacing: 3) {
                        bar(step.phase(i * 2), opacity: 1).frame(width: 22)
                        bar(step.phase(i * 2 + 1), opacity: 0.45).frame(width: 30)
                    }
                }
            }
        } else if state.prompt == nil, let today = state.todayMinutes {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("today").font(.system(size: 13)).foregroundStyle(Palette.muted)
                Text(formatMinutes(today))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ember)
            }
        } else if state.prompt == nil {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(state.energy.rounded()))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ember)
                Text("energy").font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        } else {
            Text(state.line)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private func bar(_ interval: ClosedRange<Date>, opacity: Double) -> some View {
    ProgressView(timerInterval: interval, countsDown: false) {
        EmptyView()
    } currentValueLabel: {
        EmptyView()
    }
    .progressViewStyle(.linear)
    .tint(Palette.breath.opacity(opacity))
}

public struct IslandPill: View {
    let title: String
    let color: Color
    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }
    public var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.gradient))
            .shadow(color: color.opacity(0.5), radius: 8)
    }
}

public struct EnergyBar: View {
    let energy: Double
    public init(energy: Double) { self.energy = energy }
    public var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [Palette.ember1, Palette.ember2], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, g.size.width * energy / 100))
                    .shadow(color: Palette.ember2.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 4)
    }
}

/// Drains in real time from the last update (system timer), so the island moves without the app.
public struct LiveEnergyBar: View {
    let state: IslandState
    public init(state: IslandState) { self.state = state }
    public var body: some View {
        if let end = state.energyEmpty, let drain = state.drainSeconds, drain > 0 {
            ProgressView(timerInterval: end.addingTimeInterval(-drain)...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(Palette.ember)
        } else {
            EnergyBar(energy: state.energy)
        }
    }
}

/// Expanded layout: glyph and value on top, line and one action below.
public struct IslandExpanded<Action: View>: View {
    let state: IslandState
    let action: Action

    public init(state: IslandState, @ViewBuilder action: () -> Action) {
        self.state = state
        self.action = action()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                IslandGlyph(state: state, size: 40)
                Spacer()
                IslandValue(state: state, large: true)
            }
            HStack(alignment: .center, spacing: 12) {
                IslandLine(state: state)
                Spacer(minLength: 4)
                action
            }
            if state.prompt == nil { LiveEnergyBar(state: state) }
        }
    }
}

/// Static island drawing used inside the app (gallery and in-app nudges).
public struct IslandMock<Action: View>: View {
    let state: IslandState
    let expanded: Bool
    let action: Action

    public init(state: IslandState, expanded: Bool, @ViewBuilder action: () -> Action) {
        self.state = state
        self.expanded = expanded
        self.action = action()
    }

    public var body: some View {
        Group {
            if expanded {
                IslandExpanded(state: state) { action }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 18)
                    .frame(width: 360)
                    .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(.black))
            } else {
                HStack {
                    IslandGlyph(state: state, size: 28)
                    Spacer(minLength: 90)
                    IslandValue(state: state)
                }
                .padding(.horizontal, 12)
                .frame(width: 240, height: 36)
                .background(Capsule().fill(.black))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 44 : 18, style: .continuous)
                .stroke(state.tint.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: state.tint.opacity(0.18), radius: 18)
    }
}
