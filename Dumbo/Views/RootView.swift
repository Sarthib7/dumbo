import DumboKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if model.settings.onboarded {
                TabView(selection: $model.tab) {
                    HomeView().tabItem { Label("Now", systemImage: "heart.fill") }.tag(AppModel.Tab.home)
                    SummaryView().tabItem { Label("Summary", systemImage: "chart.bar.fill") }.tag(AppModel.Tab.summary)
                    SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(AppModel.Tab.settings)
                }
                .tint(Palette.ember2)
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .top) { NudgeOverlay() }
        .statusBarHidden(model.data.activePrompt != nil && model.exercise == nil)
        .fullScreenCover(item: $model.exercise) { kind in ExerciseView(kind: kind) }
        .sheet(isPresented: $model.showGallery) { IslandGalleryView() }
        .onChangeOf(phase) { model.setActive($0 == .active) }
        .onOpenURL { model.open($0) }
    }
}

/// While the app is open iOS hides our Live Activity, so the app draws the same island itself.
struct NudgeOverlay: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            if let prompt = model.data.activePrompt, model.exercise == nil {
                let state = model.island
                IslandMock(state: state, expanded: true) {
                    if let title = state.actionTitle {
                        Button { model.primary(prompt.kind) } label: {
                            IslandPill(title: title, color: Palette.color(for: prompt.kind))
                        }
                    }
                }
                .onTapGesture { model.start(prompt.kind) }
                .gesture(DragGesture().onEnded { if $0.translation.height < -20 { model.skipPrompt() } })
                .transition(.scale(scale: 0.3, anchor: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 10)
        .ignoresSafeArea()
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: model.data.activePrompt)
    }
}

extension View {
    /// `onChange` that works on iOS 16 and 17+.
    @ViewBuilder
    func onChangeOf<V: Equatable>(_ value: V, perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value) { _, new in perform(new) }
        } else {
            onChange(of: value, perform: perform)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.panel))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }
}

struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.system(size: 11, weight: .medium)).kerning(0.6).foregroundStyle(Palette.muted)
    }
}
