import Foundation

/// JSON file in the App Group container, shared by the app and its extensions. Never leaves the device.
public final class DumboStore: @unchecked Sendable {
    public static let appGroup = "group.com.sarthib7.dumbo"
    public static let shared = DumboStore()
    public static let didChange = Notification.Name("DumboStoreDidChange")

    public let url: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let fm = FileManager.default
            let local = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let base = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) ?? local
            try? fm.createDirectory(at: base, withIntermediateDirectories: true)
            let file = base.appendingPathComponent("dumbo.json")
            self.url = file
            // Builds signed without the App Group save locally; carry that data over once the group exists.
            let localFile = local.appendingPathComponent("dumbo.json")
            if base != local, !fm.fileExists(atPath: file.path), fm.fileExists(atPath: localFile.path) {
                try? fm.moveItem(at: localFile, to: file)
            }
        }
    }

    public func load() -> DumboData {
        var result = DumboData()
        coordinate(write: false) { result = self.read() }
        return result
    }

    public func save(_ data: DumboData) {
        coordinate(write: true) { self.write(data) }
    }

    /// Coordinated read-modify-write, safe across the app and extensions.
    @discardableResult
    public func update(_ body: (inout DumboData) -> Void) -> DumboData {
        var data = DumboData()
        coordinate(write: true) {
            data = self.read()
            body(&data)
            self.write(data)
        }
        NotificationCenter.default.post(name: Self.didChange, object: nil)
        return data
    }

    private func read() -> DumboData {
        guard let raw = try? Data(contentsOf: url),
              let data = try? decoder.decode(DumboData.self, from: raw) else { return DumboData() }
        return data
    }

    private func write(_ data: DumboData) {
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    private func coordinate(write: Bool, _ body: () -> Void) {
        let c = NSFileCoordinator()
        var error: NSError?
        if write {
            c.coordinate(writingItemAt: url, options: .forMerging, error: &error) { _ in body() }
        } else {
            c.coordinate(readingItemAt: url, options: [], error: &error) { _ in body() }
        }
        if error != nil { body() }
    }
}
