import DumboKit
import SwiftUI

/// Wordless breathing: 4 s in, 1 s hold, 5 s out, three breaths.
struct BreatheView: View {
    static let cycle = 10.0
    static let breaths = 3
    let onDone: () -> Void
    @State private var start = Date()

    static func level(_ phase: Double) -> Double {
        if phase < 4 { return ease(phase / 4) }
        if phase < 5 { return 1 }
        return 1 - ease((phase - 5) / 5)
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = frozenTime ?? tl.date.timeIntervalSince(start)
            let phase = t.truncatingRemainder(dividingBy: Self.cycle)
            let lvl = Self.level(phase)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.breath.opacity(0.5), Color(red: 1, green: 0.42, blue: 0.54).opacity(0.18), .clear],
                                         center: .center, startRadius: 0, endRadius: 230))
                    .frame(width: 460, height: 460)
                    .scaleEffect(0.55 + 0.55 * lvl)
                    .blur(radius: 24)
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    drawRipples(ctx, c, phase)
                    drawParticles(ctx, c, phase, t)
                }
                BlobShape(time: t)
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.48, blue: 0.58), Color(red: 0.65, green: 0.55, blue: 1), Color(red: 0.37, green: 0.82, blue: 1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(BlobShape(time: t).fill(RadialGradient(colors: [.white.opacity(0.5), .clear], center: .init(x: 0.32, y: 0.28), startRadius: 0, endRadius: 60)))
                    .frame(width: 120, height: 120)
                    .scaleEffect(0.6 + 0.9 * lvl)
                    .shadow(color: Palette.breath.opacity(0.7), radius: 30 + 20 * lvl)
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
        .task {
            try? await Task.sleep(for: .seconds(Self.cycle * Double(Self.breaths)))
            onDone()
        }
    }

    func drawParticles(_ ctx: GraphicsContext, _ c: CGPoint, _ phase: Double, _ t: Double) {
        let n = 26
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi + sin(Double(i) * 12.9) * 0.3
            let jitter = 0.7 + 0.3 * abs(sin(Double(i) * 7.3))
            var r: Double
            var alpha: Double
            if phase < 4 {
                let p = phase / 4
                r = (190 - 120 * ease(p)) * jitter
                alpha = sin(.pi * p) * 0.9
            } else if phase < 5 {
                continue
            } else {
                let p = (phase - 5) / 5
                r = (90 + 150 * ease(p)) * jitter
                alpha = sin(.pi * p) * 0.7
            }
            r += 4 * sin(t * 1.3 + Double(i))
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            let s = 2 + 1.6 * abs(sin(Double(i) * 3.1))
            ctx.fill(Path(ellipseIn: CGRect(x: pt.x - s / 2, y: pt.y - s / 2, width: s, height: s)),
                     with: .color(.white.opacity(alpha)))
        }
    }

    func drawRipples(_ ctx: GraphicsContext, _ c: CGPoint, _ phase: Double) {
        guard phase >= 5 else { return }
        for k in 0..<2 {
            let p = (phase - 5 - Double(k) * 1.2) / 3.8
            guard p > 0, p < 1 else { continue }
            let r = 90 + 140 * ease(p)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(Palette.breath.opacity(0.45 * (1 - p))), lineWidth: 1.5)
        }
    }
}

/// A soft circle whose outline wobbles slowly.
struct BlobShape: Shape {
    var time: Double

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 72
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let r = base * (1 + 0.055 * sin(3 * a + time * 1.1) + 0.035 * sin(2 * a - time * 0.7) + 0.02 * sin(5 * a + time * 0.5))
            let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }
}
