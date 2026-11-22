import SwiftUI

/// The Dumbo pulse heart, drawn in a 24×24 unit space.
public struct HeartShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var path = Path()
        path.move(to: p(12, 21))
        path.addCurve(to: p(2.3, 11.5), control1: p(12, 21), control2: p(4.5, 16.3))
        path.addCurve(to: p(6.8, 4), control1: p(0.7, 7.8), control2: p(3, 4))
        path.addCurve(to: p(12, 7), control1: p(9.1, 4), control2: p(10.8, 5.3))
        path.addCurve(to: p(17.2, 4), control1: p(13.2, 5.3), control2: p(14.9, 4))
        path.addCurve(to: p(21.7, 11.5), control1: p(21, 4), control2: p(23.3, 7.8))
        path.addCurve(to: p(12, 21), control1: p(19.5, 16.3), control2: p(12, 21))
        path.closeSubpath()
        return path
    }
}

public struct PulseLine: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let o = CGPoint(x: rect.midX - 12 * s, y: rect.midY - 12 * s)
        let pts: [(CGFloat, CGFloat)] = [(2.5, 12.2), (7.5, 12.2), (9.1, 8.8), (11.5, 15.8), (13.7, 10.6), (15, 12.2), (21.5, 12.2)]
        var path = Path()
        for (i, pt) in pts.enumerated() {
            let q = CGPoint(x: o.x + pt.0 * s, y: o.y + pt.1 * s)
            i == 0 ? path.move(to: q) : path.addLine(to: q)
        }
        return path
    }
}

/// Heart that fills from the bottom with energy (0...100).
public struct HeartView: View {
    var energy: Double
    var pulse: Bool
    var glow: Bool

    public init(energy: Double, pulse: Bool = true, glow: Bool = true) {
        self.energy = energy
        self.pulse = pulse
        self.glow = glow
    }

    public var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let e = max(0, min(1, energy / 100))
            ZStack {
                HeartShape().fill(Palette.ember2.opacity(0.2))
                HeartShape().fill(Palette.ember)
                    .mask(alignment: .bottom) { Rectangle().frame(height: s * (3 + 17 * e) / 24) }
                HeartShape().stroke(Palette.ember, style: StrokeStyle(lineWidth: max(1, s * 0.055), lineJoin: .round))
                if pulse && s >= 28 {
                    PulseLine().stroke(.black.opacity(0.8), style: StrokeStyle(lineWidth: s * 0.065, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(width: s, height: s)
            .shadow(color: glow ? Palette.ember2.opacity(0.6) : .clear, radius: s / 9)
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Solid logo mark.
public struct LogoMark: View {
    public init() {}
    public var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                HeartShape().fill(Palette.ember)
                PulseLine().stroke(Color(white: 0.055), style: StrokeStyle(lineWidth: s * 0.07, lineCap: .round, lineJoin: .round))
            }
            .shadow(color: Palette.ember2.opacity(0.55), radius: s / 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
