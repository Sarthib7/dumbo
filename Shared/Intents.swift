import AppIntents
import DumboKit
import Foundation

/// Island buttons. LiveActivityIntents run in the app's process, offline.
@available(iOS 17.0, *)
struct LogGlassIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log a glass of water"

    func perform() async throws -> some IntentResult {
        let data = DumboStore.shared.update { DumboEngine.logGlass(at: .now, in: &$0) }
        await IslandController.sync(data: data)
        return .result()
    }
}

@available(iOS 17.0, *)
struct CompletePromptIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish break"

    @Parameter(title: "Kind") var kind: String

    init() {}
    init(kind: PromptKind) { self.kind = kind.rawValue }

    func perform() async throws -> some IntentResult {
        let k = PromptKind(rawValue: kind) ?? .eyes
        let data = DumboStore.shared.update { data in
            if k == .empty { DumboEngine.skip(at: .now, in: &data) } else { DumboEngine.complete(k, at: .now, in: &data) }
        }
        await IslandController.sync(data: data)
        return .result()
    }
}

/// Plays the breathing exercise inside the island: one update per inhale/exhale, then credits the break.
@available(iOS 17.0, *)
struct StartBreatheIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Breathe in the island"

    func perform() async throws -> some IntentResult {
        let start = Date.now
        let total = Double(IslandState.breaths) * (IslandState.inhaleSeconds + IslandState.exhaleSeconds)
        var state = IslandState.make(from: DumboStore.shared.load(), at: start)
        for step in 0..<IslandState.breathSteps {
            state = state.breathing(step: step, at: .now)
            // If iOS stops this intent early, the island falls back to resting on its own.
            await IslandController.show(state, staleDate: start.addingTimeInterval(total + 3))
            guard let end = state.breath?.end,
                  (try? await Task.sleep(for: .seconds(end.timeIntervalSinceNow))) != nil else { return .result() }
        }
        let data = DumboStore.shared.update { DumboEngine.complete(.breathe, at: .now, in: &$0) }
        await IslandController.sync(data: data)
        return .result()
    }
}
