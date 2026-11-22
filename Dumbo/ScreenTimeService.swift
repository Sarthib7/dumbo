import DeviceActivity
import DumboKit
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityName {
    static let daily = Self("daily")
}

/// Screen Time permission, app selection and the daily monitoring schedule.
@MainActor
final class ScreenTimeService: ObservableObject {
    static let shared = ScreenTimeService()
    private static let selectionKey = "familySelection"

    @Published var selection: FamilyActivitySelection
    @Published private(set) var status: AuthorizationStatus
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults(suiteName: DumboStore.appGroup) ?? .standard

    init() {
        status = AuthorizationCenter.shared.authorizationStatus
        if let raw = defaults.data(forKey: Self.selectionKey),
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: raw) {
            selection = saved
        } else {
            selection = FamilyActivitySelection()
        }
    }

    var isMonitoring: Bool { DeviceActivityCenter().activities.contains(.daily) }
    var hasSelection: Bool {
        !(selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty)
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        status = AuthorizationCenter.shared.authorizationStatus
    }

    func save(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let raw = try? JSONEncoder().encode(newSelection) { defaults.set(raw, forKey: Self.selectionKey) }
        startMonitoring()
    }

    func startMonitoring() {
        guard hasSelection else { return }
        let events = Dictionary(uniqueKeysWithValues: ScreenTimeEvents.thresholds.map { m in
            (DeviceActivityEvent.Name(ScreenTimeEvents.name(for: m)),
             DeviceActivityEvent(applications: selection.applicationTokens,
                                 categories: selection.categoryTokens,
                                 webDomains: selection.webDomainTokens,
                                 threshold: DateComponents(hour: m / 60, minute: m % 60)))
        })
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59),
                                              repeats: true)
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
