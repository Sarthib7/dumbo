import DumboKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Tab: Hashable { case home, summary, settings }

    @Published private(set) var data: DumboData
    @Published var now = Date()
    @Published var tab: Tab = .home
    @Published var exercise: PromptKind?
    @Published var showGallery = false
    @Published var summaryWeek = false

    private let store = DumboStore.shared
    private var ticker: Timer?

    init() {
        data = store.load()
        applyLaunchArguments()
        scheduleTicker()
        NotificationCenter.default.addObserver(forName: DumboStore.didChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    var settings: Settings { data.settings }
    var session: Session? { DumboEngine.currentSession(at: now, in: data) }
    var energy: Double { session?.energy ?? 100 }
    var island: IslandState { IslandState.make(from: data, at: now) }
    var today: DaySummary { Summarizer.day(now, data: data) }
    var week: WeekSummary { Summarizer.week(endingOn: now, data: data) }

    var minutesToNextNudge: Int {
        guard let s = session else { return settings.promptEveryMinutes }
        return max(0, settings.promptEveryMinutes - (s.minutes - s.lastPromptMinute))
    }

    func reload() { data = store.load() }

    func mutate(alert: Bool = false, _ body: (inout DumboData) -> Void) {
        data = store.update(body)
        let snapshot = data
        Task { await IslandController.sync(data: snapshot, alert: alert) }
    }

    // MARK: Actions

    func start(_ kind: PromptKind) { exercise = kind == .empty ? .breathe : kind }

    func finish(_ kind: PromptKind) {
        mutate { DumboEngine.complete(kind, at: .now, in: &$0) }
        exercise = nil
    }

    func closeExercise() { exercise = nil }

    func logGlass() { mutate { DumboEngine.logGlass(at: .now, in: &$0) } }

    func skipPrompt() { mutate { DumboEngine.skip(at: .now, in: &$0) } }

    /// The single button on the island.
    func primary(_ kind: PromptKind) {
        switch kind {
        case .breathe: start(.breathe)
        case .sip: logGlass()
        case .eyes: finish(.eyes)
        case .empty: skipPrompt()
        }
    }

    func update(_ change: (inout Settings) -> Void) {
        let wasDemo = settings.demo
        mutate { change(&$0.settings) }
        if settings.demo != wasDemo { scheduleTicker() }
    }

    /// Ticks once a second only in demo mode, every 30 s otherwise, and not at all in the background.
    private func scheduleTicker() {
        ticker?.invalidate()
        ticker = nil
        guard isActive else { return }
        let t = Timer(timeInterval: settings.demo ? 1 : 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = settings.demo ? 0.1 : 5
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private var isActive = true

    func setActive(_ active: Bool) {
        isActive = active
        scheduleTicker()
        if active { becameActive() }
    }

    func becameActive() {
        reload()
        now = Date()
        guard settings.onboarded else { return }
        data = store.update { DumboEngine.trim(at: .now, in: &$0) }
        IslandController.start(data: data)
        let snapshot = data
        Task { await IslandController.sync(data: snapshot) }
    }

    func restartIsland() {
        Task {
            await IslandController.endAll()
            IslandController.start(data: data)
        }
    }

    func open(_ url: URL) {
        guard let kind = PromptKind(rawValue: url.host() ?? "") else { return }
        start(kind)
    }

    func loadSampleWeek() {
        var sample = SampleData.make(now: .now, settings: settings)
        mutate { data in
            sample.cursor = data.cursor
            data = sample
        }
    }

    func resetAll() {
        var fresh = DumboData()
        fresh.settings = settings
        // Screen Time thresholds are cumulative per day, so keep the cursor to avoid recounting cleared minutes.
        mutate { data in
            fresh.cursor = data.cursor
            data = fresh
        }
    }

    // MARK: Demo

    /// In demo mode every real second counts as one minute of screen use.
    private func tick() {
        now = Date()
        guard settings.demo else {
            // The monitor extension writes from another process, so pick up its changes here.
            reload()
            if data.activePrompt != nil, now.timeIntervalSince(data.activePrompt!.started) > DumboEngine.promptTimeout {
                mutate { DumboEngine.expirePrompt(at: .now, in: &$0) }
            }
            return
        }
        guard exercise == nil else { return }
        var due: PromptKind?
        mutate(alert: false) { data in
            due = DumboEngine.recordUse(at: .now, in: &data)
            if let due { DumboEngine.show(due, at: .now, in: &data) }
        }
        if due != nil {
            let snapshot = data
            Task { await IslandController.sync(data: snapshot, alert: true) }
        }
    }

    // MARK: Screenshots / UI tests: -seed YES -screen today|week|settings|gallery|breathe|sip|eyes|nudge-<kind>

    private func applyLaunchArguments() {
        let d = UserDefaults.standard
        if d.bool(forKey: "seed") {
            var s = Settings()
            s.onboarded = true
            data = SampleData.make(now: .now, settings: s)
            store.save(data)
        }
        if let style = d.string(forKey: "style").flatMap(ParticleStyle.init(rawValue:)) {
            data.settings.style = style
            store.save(data)
        }
        if d.bool(forKey: "onboarding") {
            data.settings.onboarded = false
            store.save(data)
        }
        switch d.string(forKey: "screen") ?? "" {
        case "today": tab = .summary
        case "week": tab = .summary; summaryWeek = true
        case "settings": tab = .settings
        case "gallery": showGallery = true
        case "breathe": exercise = .breathe
        case "sip": exercise = .sip
        case "eyes": exercise = .eyes
        case let s where s.hasPrefix("nudge-"):
            if let k = PromptKind(rawValue: String(s.dropFirst(6))) {
                DumboEngine.recordUse(minutes: 12, at: .now, in: &data)
                DumboEngine.show(k, at: .now, in: &data)
                store.save(data)
            }
        default: break
        }
    }
}
