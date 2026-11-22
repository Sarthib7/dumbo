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
