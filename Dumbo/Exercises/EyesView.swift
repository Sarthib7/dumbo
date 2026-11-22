import DumboKit
import SwiftUI

/// Far/near focus drill: the dot drifts to the horizon (far) and back close (near) for 20 s.
struct EyesView: View {
    static let duration = 20.0
    static let cycle = 5.0
    let line: String
    let onDone: () -> Void
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            let p = t.truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
            let far = p < 0.5 ? ease(p / 0.5) : 1 - ease((p - 0.5) / 0.5)
            let left = max(0, Self.duration - t)
            VStack(spacing: 0) {
                Text(line)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 90)
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [Palette.eyes.opacity(0), Palette.eyes.opacity(0.5), Palette.eyes.opacity(0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .offset(y: -90)
                    Circle()
                        .fill(RadialGradient(colors: [.white, Palette.eyes, Palette.eyes.opacity(0.6)], center: .center, startRadius: 0, endRadius: 50))
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.1 - 0.95 * far)
                        .offset(y: 70 - 160 * far)
                        .shadow(color: Palette.eyes.opacity(0.8), radius: 30 * (1 - far) + 6)
                        .opacity(1 - 0.35 * far)
                }
                .frame(height: 300)
                Spacer()
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                    Circle().trim(from: 0, to: left / Self.duration)
                        .stroke(Palette.eyes, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(ceil(left)))").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                }
                .frame(width: 64, height: 64)
                Button(action: finish) { IslandPill(title: "done", color: Palette.eyes).scaleEffect(1.2) }
                    .padding(.top, 22).padding(.bottom, 50)
            }
        }
        .task {
            guard (try? await Task.sleep(for: .seconds(Self.duration))) != nil else { return }
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
