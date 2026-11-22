import Foundation

/// Threshold schedule for the Screen Time monitor: every minute for 3 h, then every 3 min up to 12 h.
public enum ScreenTimeEvents {
    /// Each threshold wakes the monitor once, so checkpoints are every 2 min for 4 h, then every 5 min.
    public static let thresholds: [Int] = Array(stride(from: 2, through: 240, by: 2)) + Array(stride(from: 245, through: 720, by: 5))

    public static func name(for minutes: Int) -> String { "m\(minutes)" }

    public static func minutes<N: RawRepresentable>(from name: N) -> Int? where N.RawValue == String {
        guard name.rawValue.hasPrefix("m") else { return nil }
        return Int(name.rawValue.dropFirst())
    }
}
