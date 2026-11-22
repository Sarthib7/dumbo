import DumboKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 10) {
                    LogoMark().frame(width: 26, height: 26)
                    Text("dumbo").font(.system(size: 22, weight: .bold, design: .rounded))
                    Spacer()
                    if model.settings.demo {
                        Text("DEMO · 2 s = 1 min").font(.system(size: 10, weight: .bold)).foregroundStyle(.black)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Palette.ember))
                    }
                }

                VStack(spacing: 6) {
                    MorphView(shape: .heart, energy: model.energy, style: model.settings.style)
                        .frame(width: 220, height: 220)
                    Text("\(Int(model.energy.rounded()))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ember)
                        .contentTransition(.numericText())
                    Text(model.session == nil ? "fresh session, full energy" : "energy this session")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    stat("this session", formatMinutes(model.session?.minutes ?? 0))
                    stat("today", formatMinutes(model.today.screenMinutes))
                    stat("next nudge", "\(model.minutesToNextNudge)m")
                }

                HStack(spacing: 10) {
                    tally("drop.fill", model.today.glasses, "water", Palette.water)
                    tally("wind", model.today.breaths, "breaths", Palette.breath)
                    tally("eye", model.today.eyeBreaks, "eyes", Palette.eyes)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Caption("take a break")
                    HStack(spacing: 10) {
                        BreakTile(kind: .breathe, title: "breathe")
                        BreakTile(kind: .sip, title: "sip")
                        BreakTile(kind: .eyes, title: "look far")
                    }
                }

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Caption("water today")
                            Text("\(model.island.glasses) of \(model.settings.waterGoal) glasses")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Spacer()
                        Button { model.logGlass() } label: { IslandPill(title: "+ glass", color: Palette.water) }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black)
    }

    func tally(_ symbol: String, _ n: Int, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12))
            Text("\(n)").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Palette.muted)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
    }

    func stat(_ label: String, _ value: String) -> some View {
        Card {
            Caption(label)
            Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }
}

struct BreakTile: View {
    @EnvironmentObject var model: AppModel
    let kind: PromptKind
    let title: String

    var body: some View {
        Button { model.start(kind) } label: {
            VStack(spacing: 10) {
                IslandGlyph(state: IslandState(sessionStart: .now, energy: 100, prompt: kind, promptStarted: .now,
                                               glasses: 5, waterGoal: 8), size: 36)
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.panel))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.color(for: kind).opacity(0.25)))
        }
    }
}
