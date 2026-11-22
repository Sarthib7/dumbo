import Foundation

public enum LineDeck {
    static let lines: [Tone: [PromptKind: [String]]] = [
        .fun: [
            .breathe: ["deep breath?", "inhale the good stuff", "breathe like you mean it"],
            .sip: ["sip sip hooray", "hydrate or diedrate", "your plants drink more than you"],
            .eyes: ["look far away. spot 5 blue things.", "find the farthest thing and wave at it", "eyes off. count 3 windows."],
            .empty: ["battery's empty. yours, not the phone's.", "you've been scrolled.", "the feed will survive without you."],
        ],
        .flirty: [
            .breathe: ["breathe with me?", "slow down, gorgeous", "one deep breath. for me."],
            .sip: ["you're cute when you're hydrated", "drink up, hot stuff", "a sip looks good on you"],
            .eyes: ["look at something far. not as pretty as you, but still.", "eyes up. the world wants to see you.", "find something far and blink at it"],
            .empty: ["you've been staring at that screen more than at me.", "put me down. i'll wait.", "go touch grass. i'll be here."],
        ],
        .calm: [
            .breathe: ["deep breath", "breathe in, slowly", "let your shoulders drop"],
            .sip: ["time for some water", "a glass of water", "stay hydrated"],
            .eyes: ["look into the distance", "rest your eyes on something far", "notice five things around you"],
            .empty: ["time for a real break", "your energy is low", "step away for a few minutes"],
        ],
    ]

    public static func line(_ kind: PromptKind, tone: Tone, seed: Int = Int.random(in: 0..<1000)) -> String {
        let pool = lines[tone]?[kind] ?? ["take a break"]
        return pool[abs(seed) % pool.count]
    }

    public static func compact(_ kind: PromptKind) -> String {
        switch kind {
        case .breathe: "breathe"
        case .sip: "sip?"
        case .eyes: "look far"
        case .empty: "recharge"
        }
    }
}
