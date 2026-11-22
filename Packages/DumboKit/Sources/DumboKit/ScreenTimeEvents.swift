import Foundation

/// Threshold schedule for the Screen Time monitor: every minute for 3 h, then every 3 min up to 12 h.
public enum ScreenTimeEvents {
    public static let thresholds: [Int] = Array(1...180) + Array(stride(from: 183, through: 720, by: 3))

    public static func name(for minutes: Int) -> String { "m\(minutes)" }

    public static func minutes<N: RawRepresentable>(from name: N) -> Int? where N.RawValue == String {
        guard name.rawValue.hasPrefix("m") else { return nil }
        return Int(name.rawValue.dropFirst())
    }
}
