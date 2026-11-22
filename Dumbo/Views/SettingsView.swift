import DumboKit
import FamilyControls
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var screenTime = ScreenTimeService.shared
    @State private var picking = false
    @State private var pickerSelection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Empty after", selection: binding(\.mode)) {
                        ForEach(Mode.allCases) { Text("\($0.title) \(Int($0.drainMinutes))m").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Energy") } footer: { Text("How long the screen can stay on before your energy hits 0%.") }

                Section("Nudges") {
                    Picker("Style", selection: binding(\.style)) {
                        ForEach(ParticleStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Tone", selection: binding(\.tone)) {
                        ForEach(Tone.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("Every \(model.settings.promptEveryMinutes) min", value: binding(\.promptEveryMinutes), in: 5...30, step: 5)
                    Stepper("Water goal: \(model.settings.waterGoal) glasses", value: binding(\.waterGoal), in: 4...14)
                    Stepper("Daily goal: \(formatMinutes(model.settings.dailyGoalMinutes))", value: binding(\.dailyGoalMinutes), in: 30...600, step: 30)
                }

                Section {
                    LabeledContent("Permission", value: statusText)
                    Button(screenTime.hasSelection ? "Change watched apps" : "Choose apps to watch") {
                        Task {
                            if screenTime.status != .approved { await screenTime.requestAuthorization() }
                            pickerSelection = screenTime.selection
                            picking = screenTime.status == .approved
                        }
                    }
                    if let e = screenTime.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
                } header: { Text("Screen Time") } footer: {
                    Text("Pick “All apps & categories” to count all screen-on time. Needs a real iPhone.")
                }

                Section("Island") {
                    Button("Preview island states") { model.showGallery = true }
                    Button("Restart Live Activity") { model.restartIsland() }
                }

                Section {
                    Button("Reset all data", role: .destructive) { model.resetAll() }
                } header: { Text("Data") } footer: { Text("Everything stays on this iPhone. Dumbo has no account and no server.") }
            }
            .navigationTitle("Settings")
            .familyActivityPicker(isPresented: $picking, selection: $pickerSelection)
            .onChangeOf(picking) { open in if !open { screenTime.save(pickerSelection) } }
        }
    }

    var statusText: String {
        switch screenTime.status {
        case .approved: screenTime.isMonitoring ? "On" : "Allowed"
        case .denied: "Denied"
        default: "Not set"
        }
    }

    func binding<T>(_ key: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: key] }, set: { v in model.update { $0[keyPath: key] = v } })
    }
}

struct IslandGalleryView: View {
    @Environment(\.dismiss) private var dismiss

    var states: [(String, IslandState)] {
        let start = Date().addingTimeInterval(-14 * 60)
        let now = Date().addingTimeInterval(-3)
        return [
            ("Resting", IslandState(sessionStart: start, energy: 69)),
            ("Breathe", IslandState(sessionStart: start, energy: 58, prompt: .breathe, promptStarted: now, line: "deep breath?")),
            ("Breathing (in island)", IslandState(sessionStart: start, energy: 58).breathing(start: now.addingTimeInterval(-12), step: 2)),
            ("Sip break", IslandState(sessionStart: start, energy: 52, prompt: .sip, promptStarted: now, line: "sip sip hooray", glasses: 3)),
            ("Eye break", IslandState(sessionStart: start, energy: 45, prompt: .eyes, promptStarted: now, line: "look far away. spot 5 blue things.")),
            ("Out of energy", IslandState(sessionStart: start, energy: 0, prompt: .empty, promptStarted: now, line: "battery's empty. yours, not the phone's.")),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 26) {
                    ForEach(states, id: \.0) { name, state in
                        VStack(spacing: 12) {
                            Text(name.uppercased()).font(.system(size: 11, weight: .semibold)).kerning(0.8)
                                .foregroundStyle(Palette.color(for: state.prompt)).frame(maxWidth: .infinity, alignment: .leading)
                            IslandMock(state: state, expanded: false) { EmptyView() }
                            IslandMock(state: state, expanded: true) {
                                if let t = state.actionTitle { IslandPill(title: t, color: Palette.color(for: state.prompt)) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(white: 0.04))
            .navigationTitle("Island states")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
