import DumboKit
import SwiftUI

/// Wordless breathing: the heart's dots become an orb that swells for 4 s, holds 1 s and shrinks for 5 s. Three breaths.
struct BreatheView: View {
    static let cycle = 10.0
    static let breaths = 3
    let style: ParticleStyle
    let onDone: () -> Void
    @State private var start = Date()

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: frozenTime != nil)) { tl in
                let t = frozenTime ?? tl.date.timeIntervalSince(start)
                let lvl = breathLevel(t)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.breath.opacity(0.45), Color(red: 1, green: 0.42, blue: 0.54).opacity(0.16), .clear],
                                             center: .center, startRadius: 0, endRadius: 230))
                        .frame(width: 460, height: 460)
                        .scaleEffect(0.55 + 0.55 * lvl)
                        .blur(radius: 24)
                    VStack {
                        Text(LineDeck.line(.breathe, tone: .fun, seed: 0))
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.muted)
                            .opacity(t < 3 ? 1 : max(0, 1 - (t - 3)))
                            .padding(.top, 70)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(0..<Self.breaths, id: \.self) { i in
                                let fill = max(0, min(1, (t - Double(i) * Self.cycle) / Self.cycle))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.12))
                                    Capsule().fill(Palette.breath).frame(width: 28 * fill)
                                }
                                .frame(width: 28, height: 3)
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
            }
            MorphView(shape: .breathe, style: style, from: .heart, freeze: frozenTime)
                .frame(width: 320, height: 320)
        }
        .task {
            guard (try? await Task.sleep(for: .seconds(Self.cycle * Double(Self.breaths)))) != nil else { return }
            onDone()
        }
    }

    func breathLevel(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: Self.cycle)
        if p < 4 { return ease(p / 4) }
        if p < 5 { return 1 }
        return 1 - ease((p - 5) / 5)
    }
}
