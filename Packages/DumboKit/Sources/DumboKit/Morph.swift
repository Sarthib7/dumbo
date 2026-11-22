import SwiftUI

/// One particle system for every state: the same dots rearrange into each shape.
public enum MorphShape: String, CaseIterable, Sendable {
    case heart, breathe, sip, eyes, empty

    public init(_ kind: PromptKind?) {
        switch kind {
        case nil: self = .heart
        case .breathe: self = .breathe
        case .sip: self = .sip
        case .eyes: self = .eyes
        case .empty: self = .empty
        }
    }
}

public enum ParticleStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case dots, ascii
    public var id: String { rawValue }
    public var title: String { self == .dots ? "Dots" : "ASCII" }
}

enum Region: UInt8 { case heart, breath, glass, water, lid, iris, outline }

struct MorphPoint {
    var x: CGFloat
    var y: CGFloat
    var region: Region
    var seed: CGFloat
}

// MARK: - Shapes, sampled once into unit-space points

enum MorphLibrary {
    private static var cache: [String: [MorphPoint]] = [:]
    private static let lock = NSLock()

    static func points(_ shape: MorphShape, count: Int) -> [MorphPoint] {
        let key = "\(shape.rawValue)-\(count)"
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        let made = make(shape, count: count)
        cache[key] = made
        return made
    }

    /// Regions in priority order, drawn in a 200×200 space.
    private static func regions(_ shape: MorphShape) -> [(Region, Path)] {
        let heart = HeartShape().path(in: CGRect(x: 8, y: 4, width: 184, height: 184))
        switch shape {
        case .heart:
            return [(.heart, heart)]
        case .empty:
            return [(.outline, heart.strokedPath(StrokeStyle(lineWidth: 10, lineJoin: .round)))]
        case .breathe:
            return [(.breath, Path(ellipseIn: CGRect(x: 36, y: 36, width: 128, height: 128)))]
        case .sip:
            var glass = Path()
            glass.addLines([CGPoint(x: 40, y: 34), CGPoint(x: 62, y: 180), CGPoint(x: 138, y: 180), CGPoint(x: 160, y: 34)])
            var water = Path()
            water.addLines([CGPoint(x: 48, y: 70), CGPoint(x: 152, y: 70), CGPoint(x: 140, y: 174), CGPoint(x: 60, y: 174)])
            water.closeSubpath()
            return [(.glass, glass.strokedPath(StrokeStyle(lineWidth: 7, lineJoin: .round))), (.water, water)]
        case .eyes:
            var lid = Path()
            lid.move(to: CGPoint(x: 14, y: 100))
            lid.addQuadCurve(to: CGPoint(x: 186, y: 100), control: CGPoint(x: 100, y: 18))
            lid.addQuadCurve(to: CGPoint(x: 14, y: 100), control: CGPoint(x: 100, y: 182))
            return [(.lid, lid.strokedPath(StrokeStyle(lineWidth: 7))),
                    (.iris, Path(ellipseIn: CGRect(x: 70, y: 70, width: 60, height: 60)))]
        }
    }

    private static let share: [Region: Double] = [.glass: 0.4, .water: 0.6, .lid: 0.62, .iris: 0.38]

    private static func make(_ shape: MorphShape, count: Int) -> [MorphPoint] {
        let regs = regions(shape)
        var buckets: [Region: [CGPoint]] = [:]
        for y in stride(from: 0, to: 200, by: 2) {
            for x in stride(from: 0, to: 200, by: 2) {
                let p = CGPoint(x: x, y: y)
                if let r = regs.first(where: { $0.1.contains(p) }) { buckets[r.0, default: []].append(p) }
            }
        }
        var rng = SplitMix(seed: 7)
        var out: [(CGPoint, Region)] = []
        for (region, _) in regs {
            guard var pts = buckets[region], !pts.isEmpty else { continue }
            pts.shuffle(using: &rng)
            let want = Int((Double(count) * (share[region] ?? 1 / Double(regs.count))).rounded())
            for i in 0..<want { out.append((pts[i * pts.count / max(1, want)], region)) }
        }
        let sampled = out.count
        while out.count < count && sampled > 0 { out.append(out[(out.count - sampled) % sampled]) }
        out = Array(out.prefix(count))
        out.sort { atan2($0.0.y - 100, $0.0.x - 100) < atan2($1.0.y - 100, $1.0.x - 100) }
        return out.enumerated().map { i, e in
            MorphPoint(x: e.0.x / 200, y: e.0.y / 200, region: e.1, seed: seed(i))
        }
    }

    static func seed(_ i: Int) -> CGFloat {
        let v = sin(Double(i) * 12.9898) * 43758.5453
        return CGFloat(v - floor(v))
    }
}

struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Motion

struct MorphMotion {
    var shape: MorphShape
    var energy: Double
    /// Sip only: fixed water level (0...1) instead of the pour/sip loop.
    var level: Double?

    static func ease(_ x: Double) -> Double { 0.5 - 0.5 * cos(.pi * max(0, min(1, x))) }

    static func breath(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: 10)
        return p < 4 ? ease(p / 4) : p < 5 ? 1 : 1 - ease((p - 5) / 5)
    }

    static func beat(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: 1.1)
        return exp(-pow(p - 0.08, 2) / 0.002) + 0.6 * exp(-pow(p - 0.3, 2) / 0.002)
    }

    /// Where a dot wants to be. `tt` is time since the shape was chosen, `t` is absolute time.
    func goal(_ p: MorphPoint, tt: Double, t: Double) -> (x: CGFloat, y: CGFloat, a: Double) {
        var x = Double(p.x), y = Double(p.y), a = 1.0
        let s = Double(p.seed)
        switch shape {
        case .heart:
            let k = 1 + 0.05 * Self.beat(t)
            x = 0.5 + (x - 0.5) * k
            y = 0.5 + (y - 0.5) * k
            let fillTop = 1 - (4 + 17 * energy / 100) / 24
            a = Double(p.y) > fillTop + 0.02 ? 1 : 0.22
        case .empty:
            a = 0.35 + 0.25 * sin(t * 2 + s * 6)
        case .breathe:
            let l = Self.breath(tt)
            let ang = atan2(y - 0.5, x - 0.5) + tt * 0.15
            let rad = hypot(x - 0.5, y - 0.5) * (0.45 + 0.65 * l) + 0.006 * sin(t * 2 + s * 9)
            x = 0.5 + cos(ang) * rad
            y = 0.5 + sin(ang) * rad
            a = 0.55 + 0.45 * l
        case .sip:
            guard p.region == .water else { break }
            let c = tt.truncatingRemainder(dividingBy: 7)
            let L: Double = level ?? (c < 2.6 ? Self.ease(c / 2.6) : c < 3.4 ? 1 : c < 6.4 ? 1 - 0.8 * Self.ease((c - 3.4) / 3) : 0.2 - 0.2 * Self.ease((c - 6.4) / 0.6))
            let h = (0.87 - y) / 0.52
            let surface = 0.87 - L * 0.52
            if h > L {
                if level == nil && c < 2.6 {
                    let f = (s + tt * 1.6).truncatingRemainder(dividingBy: 1)
                    x = 0.5 + 0.012 * sin(t * 30 + s * 9)
                    y = f * surface
                    a = 0.9
                } else {
                    a = 0
                }
            } else if h > L - 0.08 {
                y += 0.006 * sin(t * 4 + x * 20)
            }
        case .eyes:
            let c = tt.truncatingRemainder(dividingBy: 5)
            let far = c < 2.5 ? Self.ease(c / 2.5) : 1 - Self.ease((c - 2.5) / 2.5)
            if p.region == .iris {
                let k = 1 - 0.55 * far
                x = 0.5 + 0.07 * sin(tt * 0.9) + (x - 0.5) * k
                y = 0.5 + (y - 0.5) * k
            }
            let b = tt.truncatingRemainder(dividingBy: 4.3)
            if b > 4.0 { y = 0.5 + (y - 0.5) * max(0.06, abs(b - 4.15) / 0.15) }
        }
        return (CGFloat(x), CGFloat(y), a)
    }

    static func color(_ p: MorphPoint) -> Color {
        func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ k: Double) -> Color {
            let k = max(0, min(1, k))
            return Color(red: a.0 + (b.0 - a.0) * k, green: a.1 + (b.1 - a.1) * k, blue: a.2 + (b.2 - a.2) * k)
        }
        let e1 = (1.0, 0.231, 0.184), e2 = (1.0, 0.541, 0.0)
        switch p.region {
        case .heart: return mix(e2, e1, Double(p.y))
        case .outline: return Palette.ember1
        case .breath:
            let d = hypot(Double(p.x) - 0.5, Double(p.y) - 0.5) / 0.32
            return d < 0.5 ? mix((1, 0.48, 0.58), (0.616, 0.545, 1), d * 2) : mix((0.616, 0.545, 1), (0.37, 0.82, 1), (d - 0.5) * 2)
        case .glass: return Color(red: 0.88, green: 0.92, blue: 1)
        case .water: return Palette.water
        case .lid: return Palette.eyes
        case .iris: return mix((1, 1, 1), (1, 0.698, 0.247), 0.6)
        }
    }

    static func glyph(_ p: MorphPoint) -> String {
        let s = p.seed
        switch p.region {
        case .heart: return ["#", "@", "%", "*"][Int(s * 4) % 4]
        case .outline: return "."
        case .breath: return ["o", "*", "+", "."][Int(s * 4) % 4]
        case .glass: return "|"
        case .water: return "~"
        case .lid: return ["-", "=", "~"][Int(s * 3) % 3]
        case .iris: return ["@", "O", "0"][Int(s * 3) % 3]
        }
    }
}

// MARK: - Views

/// Settled shape built from plain views, so it also renders inside widgets and Live Activities.
public struct MorphGlyph: View {
    let shape: MorphShape
    let count: Int
    let energy: Double
    let level: Double?

    public init(shape: MorphShape, count: Int = 60, energy: Double = 100, level: Double? = nil) {
        self.shape = shape
        self.count = count
        self.energy = energy
        self.level = level
    }

    public var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let motion = MorphMotion(shape: shape, energy: energy, level: shape == .sip ? (level ?? 0.75) : nil)
            let settle: Double = shape == .breathe ? 4.5 : 0
            let pts = MorphLibrary.points(shape, count: count)
            let r = max(0.8, s * (count <= 60 ? 0.04 : 0.018))
            ZStack(alignment: .topLeading) {
                ForEach(pts.indices, id: \.self) { i in
                    let p = pts[i]
                    let goal = motion.goal(p, tt: settle, t: 0)
                    if goal.a > 0.02 {
                        Circle()
                            .fill(MorphMotion.color(p).opacity(goal.a))
                            .frame(width: r * 2, height: r * 2)
                            .position(x: goal.x * s, y: goal.y * s)
                    }
                }
            }
            .frame(width: s, height: s)
            .shadow(color: Palette.color(for: shape.kind).opacity(0.55), radius: s / 10)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension MorphShape {
    var kind: PromptKind? {
        switch self {
        case .heart: nil
        case .breathe: .breathe
        case .sip: .sip
        case .eyes: .eyes
        case .empty: .empty
        }
    }
}

/// Mutable particle state for the animated view.
final class MorphSim: ObservableObject {
    var xs: [CGFloat] = []
    var ys: [CGFloat] = []
    var vx: [CGFloat] = []
    var vy: [CGFloat] = []
    var alpha: [Double] = []
    var targets: [MorphPoint] = []
    var shape: MorphShape?
    var since: Double = 0
    let count: Int

    init(count: Int, from: MorphShape?) {
        self.count = count
        let start = from.map { MorphLibrary.points($0, count: count) }
        xs = (0..<count).map { start?[$0].x ?? MorphLibrary.seed($0 + 99) }
        ys = (0..<count).map { start?[$0].y ?? MorphLibrary.seed($0 + 7) }
        vx = Array(repeating: 0, count: count)
        vy = Array(repeating: 0, count: count)
        alpha = Array(repeating: start == nil ? 0 : 1, count: count)
    }

    func retarget(_ s: MorphShape, at t: Double) {
        shape = s
        since = t
        targets = MorphLibrary.points(s, count: count)
    }

    func step(_ motion: MorphMotion, t: Double, settle: Bool) {
        let tt = t - since
        for i in 0..<count {
            let g = motion.goal(targets[i], tt: tt, t: t)
            if settle {
                xs[i] = g.x; ys[i] = g.y; alpha[i] = g.a
                continue
            }
            vx[i] = (vx[i] + (g.x - xs[i]) * 0.06) * 0.82
            vy[i] = (vy[i] + (g.y - ys[i]) * 0.06) * 0.82
            xs[i] += vx[i]
            ys[i] += vy[i]
            alpha[i] += (g.a - alpha[i]) * 0.15
        }
    }
}

/// Live particle animation. Changing `shape` morphs the same dots into the new shape.
public struct MorphView: View {
    let shape: MorphShape
    let energy: Double
    let style: ParticleStyle
    let freeze: Double?
    @StateObject private var sim: MorphSim

    public init(shape: MorphShape, count: Int = 240, energy: Double = 100, style: ParticleStyle = .dots,
                from: MorphShape? = nil, freeze: Double? = nil) {
        self.shape = shape
        self.energy = energy
        self.style = style
        self.freeze = freeze
        _sim = StateObject(wrappedValue: MorphSim(count: count, from: from))
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: freeze != nil)) { tl in
            Canvas { ctx, size in
                let wall = tl.date.timeIntervalSinceReferenceDate
                if sim.shape != shape { sim.retarget(shape, at: wall) }
                let t = freeze.map { sim.since + $0 } ?? wall
                sim.step(MorphMotion(shape: shape, energy: energy, level: nil), t: t, settle: freeze != nil)
                draw(ctx, size: min(size.width, size.height))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Palette.color(for: shape.kind).opacity(0.45), radius: 14)
    }

    private func draw(_ ctx: GraphicsContext, size s: CGFloat) {
        var ctx = ctx
        if style == .ascii {
            var resolved: [String: GraphicsContext.ResolvedText] = [:]
            for i in 0..<sim.count where sim.alpha[i] > 0.02 {
                let p = sim.targets[i]
                let ch = MorphMotion.glyph(p)
                let key = "\(ch)\(p.region.rawValue)\(p.region == .heart || p.region == .breath ? Int(p.seed * 4) : 0)"
                let text = resolved[key] ?? ctx.resolve(Text(ch).font(.system(size: s / 23, weight: .bold, design: .monospaced))
                    .foregroundColor(MorphMotion.color(p)))
                resolved[key] = text
                ctx.opacity = sim.alpha[i]
                ctx.draw(text, at: CGPoint(x: sim.xs[i] * s, y: sim.ys[i] * s))
            }
        } else {
            let base = s * 0.0085 * CGFloat(240) / CGFloat(max(60, sim.count))
            for i in 0..<sim.count where sim.alpha[i] > 0.02 {
                let p = sim.targets[i]
                let r = base * (0.75 + 0.5 * p.seed)
                ctx.opacity = sim.alpha[i]
                ctx.fill(Path(ellipseIn: CGRect(x: sim.xs[i] * s - r, y: sim.ys[i] * s - r, width: 2 * r, height: 2 * r)),
                         with: .color(MorphMotion.color(p)))
            }
        }
    }
}
