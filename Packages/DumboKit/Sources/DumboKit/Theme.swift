import SwiftUI

public enum Palette {
    public static let ember1 = Color(red: 1.0, green: 0.231, blue: 0.184)   // #ff3b2f
    public static let ember2 = Color(red: 1.0, green: 0.541, blue: 0.0)     // #ff8a00
    public static let water = Color(red: 0.231, green: 0.639, blue: 1.0)    // #3ba3ff
    public static let breath = Color(red: 0.616, green: 0.545, blue: 1.0)   // #9d8bff
    public static let eyes = Color(red: 1.0, green: 0.698, blue: 0.247)     // #ffb23f
    public static let panel = Color(red: 0.067, green: 0.067, blue: 0.082)
    public static let line = Color(red: 0.145, green: 0.145, blue: 0.18)
    public static let muted = Color(red: 0.59, green: 0.59, blue: 0.65)

    public static let ember = LinearGradient(colors: [ember1, ember2], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let emberUp = LinearGradient(colors: [ember1, ember2], startPoint: .bottom, endPoint: .top)

    public static func color(for kind: PromptKind?) -> Color {
        switch kind {
        case .breathe: breath
        case .sip: water
        case .eyes: eyes
        case .empty: ember1
        case nil: ember2
        }
    }
}

public func formatMinutes(_ m: Int) -> String {
    m >= 60 ? "\(m / 60)h \(String(format: "%02d", m % 60))m" : "\(m)m"
}
