import DeviceActivity
import DumboKit
import Foundation

/// iOS wakes this extension each time cumulative screen use today crosses a threshold.
/// Each crossing is a check-in; a 5+ min gap between check-ins starts a new session.
final class DumboMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let threshold = ScreenTimeEvents.minutes(from: event) else { return }

        var due: PromptKind?
        let now = Date()
        let data = DumboStore.shared.update { data in
            let minutes = DumboEngine.minutesSinceCursor(threshold: threshold, at: now, in: &data)
            due = DumboEngine.recordUse(minutes: minutes, at: now, in: &data)
            if let due { DumboEngine.show(due, at: now, in: &data) }
            DumboEngine.trim(at: now, in: &data)
        }

        // Extensions can be suspended as soon as this returns, so wait for the island update.
        let done = DispatchSemaphore(value: 0)
        Task {
            await IslandController.sync(data: data, at: now, alert: due != nil)
            done.signal()
        }
        _ = done.wait(timeout: .now() + 5)
    }
}
