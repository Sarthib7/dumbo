import DumboKit
import FamilyControls
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var page = 0
    @State private var picking = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        VStack {
            TabView(selection: $page) {
                welcome.tag(0)
                energy.tag(1)
                style.tag(2)
                permission.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            if page < 3 {
                Button { withAnimation { page += 1 } } label: { primaryLabel("Next") }
                    .padding(.horizontal, 24).padding(.bottom, 20)
            }
        }
        .background(Color.black)
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: picking) { _, open in
            if !open {
                screenTime.save(selection)
                finish(demo: false)
            }
        }
    }

    var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            LogoMark().frame(width: 120, height: 120)
            Text("dumbo").font(.system(size: 44, weight: .bold, design: .rounded))
            Text("A tiny energy heart for your screen time.\nIt lives in the Dynamic Island.")
                .multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Spacer()
        }
        .padding(24)
    }

    var energy: some View {
        VStack(spacing: 18) {
            Spacer()
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6
                HeartView(energy: 100 - t * 100).frame(width: 140, height: 140)
            }
            Text("Energy starts when your screen turns on").font(.title3.bold()).multilineTextAlignment(.center)
            Text("It drains while the screen stays on. Short breaks fill it back up, and putting the phone down for 5 minutes starts a fresh session.")
                .multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Spacer()
        }
        .padding(24)
    }

    var style: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Your pace").font(.title3.bold())
            Picker("Mode", selection: Binding(get: { model.settings.mode }, set: { v in model.update { $0.mode = v } })) {
                ForEach(Mode.allCases) { Text("\($0.title) \(Int($0.drainMinutes))m").tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Your nudges").font(.title3.bold()).padding(.top, 10)
            Picker("Tone", selection: Binding(get: { model.settings.tone }, set: { v in model.update { $0.tone = v } })) {
                ForEach(Tone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("“\(LineDeck.line(.eyes, tone: model.settings.tone, seed: 0))”")
                .foregroundStyle(Palette.eyes).font(.headline)
            Spacer()
        }
        .padding(24)
    }

    var permission: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hourglass").font(.system(size: 54)).foregroundStyle(Palette.ember)
            Text("Count your screen time").font(.title3.bold())
            Text("Dumbo uses Apple's Screen Time to notice how long the screen has been on. Choose “All apps & categories”. Nothing leaves your iPhone.")
                .multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            Spacer()
            Button {
                Task {
                    await screenTime.requestAuthorization()
                    if screenTime.status == .approved { picking = true }
                }
            } label: { primaryLabel("Allow Screen Time") }
            if let e = screenTime.lastError { Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
            Button("Try the demo instead") { finish(demo: true) }
                .foregroundStyle(Palette.muted).padding(.bottom, 30)
        }
        .padding(24)
    }

    func primaryLabel(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Capsule().fill(Palette.ember))
    }

    func finish(demo: Bool) {
        model.update {
            $0.onboarded = true
            $0.demo = demo
        }
        model.becameActive()
    }
}
