import DumboKit
import SwiftUI

struct ExerciseView: View {
    @EnvironmentObject var model: AppModel
    let kind: PromptKind

    var body: some View {
        Color.black.ignoresSafeArea()
            .overlay {
                switch kind {
                case .breathe, .empty: BreatheView(style: model.settings.style) { model.finish(.breathe) }
                case .sip: SipView(glasses: model.island.glasses, goal: model.settings.waterGoal, style: model.settings.style) { model.finish(.sip) }
                case .eyes: EyesView(line: model.data.activePrompt?.kind == .eyes ? model.data.activePrompt!.line
                                     : LineDeck.line(.eyes, tone: model.settings.tone), style: model.settings.style) { model.finish(.eyes) }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { model.closeExercise() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.muted)
                        .frame(width: 36, height: 36).background(Circle().fill(Palette.panel))
                }
                .padding(.trailing, 20).padding(.top, 8)
            }
        .preferredColorScheme(.dark)
    }
}

/// Smooth 0→1→0 easing.
func ease(_ x: Double) -> Double { 0.5 - 0.5 * cos(.pi * max(0, min(1, x))) }

/// Screenshot helper: `-freeze 2.5` pins exercise animations to that second.
var frozenTime: Double? {
    UserDefaults.standard.object(forKey: "freeze") == nil ? nil : UserDefaults.standard.double(forKey: "freeze")
}
