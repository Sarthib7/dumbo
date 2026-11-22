import DumboKit
import SwiftUI

/// 7 s loop: the bottle tips mouth-down into the glass, pours, stands back up, then the glass is sipped three times.
struct SipView: View {
    static let loop = 7.0
    let glasses: Int
    let goal: Int
    let onDone: () -> Void
    @State private var start = Date()

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            TimelineView(.animation) { tl in
                let t = frozenTime ?? tl.date.timeIntervalSince(start).truncatingRemainder(dividingBy: Self.loop)
                Canvas { ctx, size in
                    let scale = min(size.width, size.height) / 320
                    ctx.translateBy(x: (size.width - 320 * scale) / 2, y: (size.height - 320 * scale) / 2)
                    ctx.scaleBy(x: scale, y: scale)
                    SipScene(t: t).draw(in: ctx)
                }
            }
            .frame(width: 320, height: 320)
            Text("sip sip hooray").font(.system(size: 26, weight: .bold))
            Text("\(glasses) of \(goal) glasses today").foregroundStyle(Palette.muted)
            Button(action: onDone) { IslandPill(title: "+ glass", color: Palette.water).scaleEffect(1.3) }
                .padding(.top, 10)
            Spacer()
        }
    }
}

struct SipScene {
    let t: Double

    static let pivot = CGPoint(x: 100, y: 120)
    static let k: CGFloat = 2.2
    static let tilt = 110.0
    static let glassTop: CGFloat = 175
    static let glassBottom: CGFloat = 262
    static let glassCX: CGFloat = 192
    static let glassTopW: CGFloat = 96
    static let glassBottomW: CGFloat = 76

    func seg(_ a: Double, _ b: Double) -> Double { ease((t - a) / (b - a)) }

    var bottleAngle: Double { Self.tilt * (seg(0.8, 1.6) - seg(3.6, 4.3)) }
    var pouring: Bool { t > 1.65 && t < 3.55 }
    var bottleVolume: Double { 0.85 - 0.6 * seg(1.7, 3.6) + 0.6 * seg(6.6, 7.0) }
    var glassLevel: Double {
        let filled = 0.8 * seg(1.7, 3.6)
        let sipped = 0.65 * seg(4.4, 6.6)
        return max(0, filled - sipped - 0.15 * seg(6.6, 7.0))
    }
    var glassAngle: Double {
        guard t > 4.3, t < 6.6 else { return 0 }
        let p = (t - 4.3) / 2.3 * 3
        return -12 * sin(.pi * (p - floor(p)))
    }

    func bottleTransform() -> CGAffineTransform {
        CGAffineTransform(translationX: Self.pivot.x, y: Self.pivot.y)
            .rotated(by: bottleAngle * .pi / 180)
            .scaledBy(x: Self.k, y: Self.k)
    }

    static func bottlePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -4, y: -24))
        p.addCurve(to: CGPoint(x: -12, y: -10), control1: CGPoint(x: -4, y: -20), control2: CGPoint(x: -12, y: -18))
        p.addLine(to: CGPoint(x: -12, y: 26))
        p.addQuadCurve(to: CGPoint(x: -8, y: 30), control: CGPoint(x: -12, y: 30))
        p.addLine(to: CGPoint(x: 8, y: 30))
        p.addQuadCurve(to: CGPoint(x: 12, y: 26), control: CGPoint(x: 12, y: 30))
        p.addLine(to: CGPoint(x: 12, y: -10))
        p.addCurve(to: CGPoint(x: 4, y: -24), control1: CGPoint(x: 12, y: -18), control2: CGPoint(x: 4, y: -20))
        p.addLine(to: CGPoint(x: 4, y: -34))
        p.addLine(to: CGPoint(x: -4, y: -34))
        p.closeSubpath()
        return p
    }

    var mouth: CGPoint { CGPoint(x: 0, y: -34).applying(bottleTransform()) }

    func glassPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: Self.glassCX - Self.glassTopW / 2, y: Self.glassTop))
        p.addLine(to: CGPoint(x: Self.glassCX - Self.glassBottomW / 2, y: Self.glassBottom))
        p.addLine(to: CGPoint(x: Self.glassCX + Self.glassBottomW / 2, y: Self.glassBottom))
        p.addLine(to: CGPoint(x: Self.glassCX + Self.glassTopW / 2, y: Self.glassTop))
        return p
    }

    var waterSurfaceY: CGFloat { Self.glassBottom - CGFloat(glassLevel) * (Self.glassBottom - Self.glassTop) }

    func draw(in ctx: GraphicsContext) {
        let water = Palette.water

        // Bottle: water stays level in world space and runs toward the mouth.
        let bottle = Self.bottlePath().applying(bottleTransform())
        let box = bottle.boundingRect
        var inside = ctx
        inside.clip(to: bottle)
        inside.fill(Path(bottle.boundingRect), with: .color(water.opacity(0.08)))
        let level = box.maxY - CGFloat(bottleVolume) * box.height * (bottleAngle > 60 ? 0.55 : 0.95)
        inside.fill(Path(CGRect(x: box.minX - 10, y: level, width: box.width + 20, height: box.maxY - level + 10)),
                    with: .linearGradient(Gradient(colors: [water.opacity(0.95), water.opacity(0.6)]),
                                          startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: box.maxY)))
        ctx.stroke(bottle, with: .color(water.opacity(0.95)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))

        // Stream from the mouth down to the water surface.
        if pouring {
            let m = mouth
            let wobble = 1.2 * sin(t * 40)
            let stream = Path(roundedRect: CGRect(x: m.x - 3 + wobble, y: m.y, width: 6, height: max(0, waterSurfaceY - m.y)), cornerRadius: 3)
            ctx.fill(stream, with: .linearGradient(Gradient(colors: [water, water.opacity(0.75)]),
                                                   startPoint: m, endPoint: CGPoint(x: m.x, y: waterSurfaceY)))
            for i in 0..<5 {
                let p = (t * 2.2 + Double(i) * 0.21).truncatingRemainder(dividingBy: 1)
                let dir: CGFloat = i % 2 == 0 ? 1 : -1
                let x = m.x + dir * CGFloat(6 + 14 * p) * CGFloat(1 + i % 3) / 2
                let y = waterSurfaceY - CGFloat(sin(.pi * p) * 14)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(water.opacity(1 - p)))
            }
        }

        // Glass, tipped around its base while sipping.
        var g = ctx
        let base = CGPoint(x: Self.glassCX, y: Self.glassBottom)
        g.translateBy(x: base.x, y: base.y)
        g.rotate(by: .degrees(glassAngle))
        g.translateBy(x: -base.x, y: -base.y)
        let glass = glassPath()
        var closed = glass
        closed.closeSubpath()
        var gw = g
        gw.clip(to: closed)
        if glassLevel > 0.005 {
            let y = waterSurfaceY
            gw.fill(Path(CGRect(x: 100, y: y, width: 200, height: 120)),
                    with: .linearGradient(Gradient(colors: [water.opacity(0.95), water.opacity(0.7)]),
                                          startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: Self.glassBottom)))
            gw.fill(Path(ellipseIn: CGRect(x: 120, y: y - 3, width: 150, height: 6)), with: .color(.white.opacity(0.35)))
            if t > 4.3 && t < 6.6 {
                for i in 0..<4 {
                    let p = (t * 0.9 + Double(i) * 0.27).truncatingRemainder(dividingBy: 1)
                    let bx = Self.glassCX - 20 + CGFloat(i) * 13
                    let by = Self.glassBottom - CGFloat(p) * (Self.glassBottom - y)
                    gw.stroke(Path(ellipseIn: CGRect(x: bx - 2.5, y: by - 2.5, width: 5, height: 5)), with: .color(.white.opacity(0.7 * (1 - p))), lineWidth: 1)
                }
            }
        }
        g.stroke(glass, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
    }
}
