import SwiftUI

/// Everything the Dynamic Island needs. Doubles as the Live Activity content state.
public struct IslandState: Codable, Hashable, Sendable {
    public static let breatheSeconds: TimeInterval = 30
    public static let eyesSeconds: TimeInterval = 20
    public static let breaths = 3
    public static let inhaleSeconds: TimeInterval = 4
    public static let exhaleSeconds: TimeInterval = 6

    /// One half of a breath played inside the island (iOS 17+), so the app never has to open.
    public struct BreathStep: Codable, Hashable, Sendable {
        public var index: Int
        public var start: Date
        public var end: Date
        public var inhale: Bool { index % 2 == 0 }
        public var breathsDone: Int { index / 2 }
    }

    public var sessionStart: Date
    public var energy: Double
    public var prompt: PromptKind?
    public var promptStarted: Date?
    public var line: String
    public var glasses: Int
    public var waterGoal: Int
    public var breath: BreathStep?

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

    /// The state for step `index` (even = inhale, odd = exhale) of the in-island breathing exercise.
    public func breathing(step index: Int, at date: Date) -> IslandState {
        var s = self
        s.prompt = .breathe
        s.promptStarted = s.promptStarted ?? date
        let length = index % 2 == 0 ? Self.inhaleSeconds : Self.exhaleSeconds
        s.breath = BreathStep(index: index, start: date, end: date.addingTimeInterval(length))
        return s
    }

    public static func make(from data: DumboData, at date: Date, calendar: Calendar = .current) -> IslandState {
        let session = DumboEngine.currentSession(at: date, in: data)
        let today = calendar.startOfDay(for: date)
        return IslandState(
            sessionStart: session?.start ?? date,
            energy: session?.energy ?? 100,
            prompt: data.activePrompt?.kind,
            promptStarted: data.activePrompt?.started,
            line: data.activePrompt?.line ?? "",
            glasses: data.water.filter { $0 >= today }.count,
            waterGoal: data.settings.waterGoal
        )
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
            .scaleEffect(state.breath.map { $0.inhale ? 1.15 : 0.6 } ?? 1)
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
                Text(timerInterval: state.sessionStart...state.sessionStart.addingTimeInterval(86_400), countsDown: false)
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
            HStack(spacing: 6) {
                ForEach(0..<IslandState.breaths, id: \.self) { i in
                    if i == step.breathsDone {
                        // Fills on the inhale, drains on the exhale.
                        ProgressView(timerInterval: step.start...step.end, countsDown: !step.inhale) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .progressViewStyle(.linear)
                        .tint(Palette.breath)
                        .frame(width: 44)
                    } else {
                        Capsule()
                            .fill(Palette.breath.opacity(i < step.breathsDone ? 1 : 0.18))
                            .frame(width: 26, height: 4)
                    }
                }
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
            if state.prompt == nil { EnergyBar(energy: state.energy) }
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
