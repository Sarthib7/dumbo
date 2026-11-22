#if os(iOS)
import ActivityKit
import Foundation

public struct DumboActivityAttributes: ActivityAttributes {
    public typealias ContentState = IslandState
    public init() {}
}

/// Starts and updates the Dynamic Island Live Activity. Works fully offline.
public enum IslandController {
    static var activities: [Activity<DumboActivityAttributes>] { Activity<DumboActivityAttributes>.activities }

    public static var isRunning: Bool { !activities.isEmpty }

    /// Must be called while the app is in the foreground.
    public static func start(data: DumboData, at date: Date = .now) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, activities.isEmpty else { return }
        let content = ActivityContent(state: IslandState.make(from: data, at: date), staleDate: nil)
        _ = try? Activity.request(attributes: DumboActivityAttributes(), content: content, pushType: nil)
    }

    /// Pushes the latest state. With `alert`, the island expands briefly; the sound is silent.
    public static func sync(data: DumboData, at date: Date = .now, alert: Bool = false) async {
        let state = IslandState.make(from: data, at: date)
        // A stale nudge collapses back to the resting island even if no further update arrives.
        let stale = state.promptStarted.map { $0.addingTimeInterval(DumboEngine.promptTimeout) }
        let content = ActivityContent(state: state, staleDate: stale)
        let config = alert && state.prompt != nil
            ? AlertConfiguration(title: "\(LineDeck.compact(state.prompt!))", body: "\(state.line)", sound: .named("silence.caf"))
            : nil
        for activity in activities {
            await activity.update(content, alertConfiguration: config)
        }
    }

    /// Pushes a state built by the caller, e.g. a breathing step.
    public static func show(_ state: IslandState, staleDate: Date?) async {
        for activity in activities {
            await activity.update(ActivityContent(state: state, staleDate: staleDate))
        }
    }

    public static func endAll() async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
