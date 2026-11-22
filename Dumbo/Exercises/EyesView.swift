import DumboKit
import SwiftUI

/// Far/near focus drill: the dot drifts to the horizon (far) and back close (near) for 20 s.
struct EyesView: View {
    static let duration = 20.0
    static let cycle = 5.0
    let line: String
    let style: ParticleStyle
    let onDone: () -> Void
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t = tl.date.timeIntervalSince(start)
            let left = max(0, Self.duration - t)
            VStack(spacing: 0) {
                Text(line)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 90)
                Spacer()
                MorphView(shape: .eyes, style: style, from: .heart, freeze: frozenTime)
                    .frame(width: 320, height: 300)
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
