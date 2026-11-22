import ActivityKit
import DumboKit
import SwiftUI
import WidgetKit

struct DumboLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DumboActivityAttributes.self) { context in
            IslandExpanded(state: context.state) { IslandAction(state: context.state) }
                .padding(18)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandGlyph(state: state, size: 40).padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandValue(state: state, large: true).padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            IslandLine(state: state)
                            Spacer(minLength: 4)
                            IslandAction(state: state)
                        }
                        if state.prompt == nil { EnergyBar(energy: state.energy) }
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                IslandGlyph(state: state, size: 20)
            } compactTrailing: {
                IslandValue(state: state)
            } minimal: {
                IslandGlyph(state: state, size: 18)
            }
            .widgetURL(URL(string: "dumbo://\(state.prompt?.rawValue ?? "home")"))
            .keylineTint(Palette.color(for: state.prompt))
        }
    }
}

struct IslandAction: View {
    let state: IslandState

    var body: some View {
        if let title = state.actionTitle, let kind = state.prompt {
            let pill = IslandPill(title: title, color: Palette.color(for: kind))
            switch kind {
            case .breathe:
                Link(destination: URL(string: "dumbo://breathe")!) { pill }
            case .sip:
                Button(intent: LogGlassIntent()) { pill }.buttonStyle(.plain)
            case .eyes, .empty:
                Button(intent: CompletePromptIntent(kind: kind)) { pill }.buttonStyle(.plain)
            }
        }
    }
}
