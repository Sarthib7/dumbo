import DumboKit
import SwiftUI

/// The heart's dots become a glass: water pours in as a stream, then gets sipped down. 7 s loop.
struct SipView: View {
    let glasses: Int
    let goal: Int
    let style: ParticleStyle
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MorphView(shape: .sip, style: style, from: .heart, freeze: frozenTime)
                .frame(width: 300, height: 300)
            Text("sip sip hooray").font(.system(size: 26, weight: .bold))
            Text("\(glasses) of \(goal) glasses today").foregroundStyle(Palette.muted)
            Button(action: onDone) { IslandPill(title: "+ glass", color: Palette.water).scaleEffect(1.3) }
                .padding(.top, 10)
            Spacer()
        }
    }
}
