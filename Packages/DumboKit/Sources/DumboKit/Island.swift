import SwiftUI

/// Everything the Dynamic Island needs. Doubles as the Live Activity content state.
public struct IslandState: Codable, Hashable, Sendable {
    public static let breatheSeconds: TimeInterval = 30
    public static let eyesSeconds: TimeInterval = 20

    public var sessionStart: Date
    public var energy: Double
    public var prompt: PromptKind?
    public var promptStarted: Date?
    public var line: String
    public var glasses: Int
    public var waterGoal: Int

    public init(sessionStart: Date, energy: Double, prompt: PromptKind? = nil, promptStarted: Date? = nil,
                line: String = "", glasses: Int = 0, waterGoal: Int = 8) {
        self.sessionStart = sessionStart
        self.energy = energy
        self.prompt = prompt
        self.promptStarted = promptStarted
        self.line = line
        self.glasses = glasses
        self.waterGoal = waterGoal
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
        return s
    }
    var tint: Color { Palette.color(for: prompt) }

    public var actionTitle: String? {
        switch prompt {
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
        Group {
            switch state.prompt {
            case nil: HeartView(energy: state.energy, pulse: size >= 28)
            case .empty: HeartView(energy: 0, pulse: size >= 28)
            case .breathe: BreathGlyph(start: state.promptStart, size: size)
            case .sip: GlassGlyph(fill: Double(state.glasses) / Double(max(1, state.waterGoal)), size: size)
            case .eyes: FocusGlyph(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

struct BreathGlyph: View {
    let start: Date
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.48, blue: 0.58), Palette.breath, Palette.breath.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.36))
                .padding(size * 0.14)
            Circle().stroke(Palette.breath.opacity(0.18), lineWidth: max(1.5, size * 0.07))
        }
        .shadow(color: Palette.breath.opacity(0.6), radius: size / 6)
    }
}

struct GlassShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let inset = r.width * 0.12
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - inset, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + inset, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct GlassGlyph: View {
    let fill: Double
    let size: CGFloat
    var body: some View {
        let f = max(0.12, min(1, fill))
        ZStack {
            GlassShape().fill(Palette.water.opacity(0.85))
                .mask(alignment: .bottom) { Rectangle().frame(height: size * 0.72 * f) }
            GlassShape().stroke(Palette.water, style: StrokeStyle(lineWidth: max(1.2, size * 0.06), lineJoin: .round))
        }
        .frame(width: size * 0.62, height: size * 0.72)
        .offset(y: size * 0.06)
        .overlay(alignment: .top) {
            Circle().fill(Palette.water).frame(width: size * 0.12).offset(x: size * 0.18, y: -size * 0.08)
        }
        .shadow(color: Palette.water.opacity(0.55), radius: size / 7)
    }
}

/// A near ring and a far dot on the horizon.
struct FocusGlyph: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [Palette.eyes.opacity(0), Palette.eyes.opacity(0.6), Palette.eyes.opacity(0)],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(height: max(1, size * 0.04))
            Circle().stroke(Palette.eyes.opacity(0.35), lineWidth: max(1, size * 0.04)).padding(size * 0.12)
            Circle().fill(Palette.eyes).frame(width: size * 0.2)
        }
        .shadow(color: Palette.eyes.opacity(0.7), radius: size / 7)
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
        if state.prompt == nil {
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
                    IslandGlyph(state: state, size: 20)
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
