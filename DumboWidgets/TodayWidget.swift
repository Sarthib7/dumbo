import DumboKit
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let summary: DaySummary
    let goalMinutes: Int
    let waterGoal: Int
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { entry(DumboData()) }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(entry(DumboStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let e = entry(DumboStore.shared.load())
        completion(Timeline(entries: [e], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    private func entry(_ data: DumboData) -> TodayEntry {
        TodayEntry(date: .now, summary: Summarizer.day(.now, data: data),
                   goalMinutes: data.settings.dailyGoalMinutes, waterGoal: data.settings.waterGoal)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DumboToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .widgetBackground(Color(white: 0.067))
        }
        .configurationDisplayName("Today")
        .description("Screen-on time, water, breaths and eye breaks.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayEntry

    var progress: Double { min(1, Double(entry.summary.screenMinutes) / Double(max(1, entry.goalMinutes))) }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dumbo").font(.caption2).foregroundStyle(.secondary)
                Text(formatMinutes(entry.summary.screenMinutes)).font(.headline)
                Text("\(entry.summary.glasses) glasses · \(entry.summary.promptsDone) breaks").font(.caption2)
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 8) {
                ring.frame(width: 54, height: 54)
                Spacer(minLength: 0)
                Text("TODAY").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                Text(formatMinutes(entry.summary.screenMinutes)).font(.system(size: 22, weight: .bold, design: .rounded))
                dots
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: 16) {
                ring.frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 5) {
                    Text("TODAY").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                    Text(formatMinutes(entry.summary.screenMinutes)).font(.system(size: 26, weight: .bold, design: .rounded))
                    dots
                    EnergyBar(energy: progress * 100).padding(.top, 4)
                    Text("\(Int(progress * 100))% of your \(formatMinutes(entry.goalMinutes)) goal")
                        .font(.system(size: 10.5)).foregroundStyle(Palette.muted)
                }
            }
        }
    }

    var ring: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
            Circle().trim(from: 0, to: entry.summary.averageEnergy / 100)
                .stroke(Palette.ember, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            HeartView(energy: entry.summary.averageEnergy, pulse: false).padding(18)
        }
    }

    var dots: some View {
        HStack(spacing: 10) {
            Label("\(entry.summary.glasses)/\(entry.waterGoal)", systemImage: "drop.fill").foregroundStyle(Palette.water)
            Label("\(entry.summary.breaths)", systemImage: "wind").foregroundStyle(Palette.breath)
            Label("\(entry.summary.eyeBreaks)", systemImage: "eye.fill").foregroundStyle(Palette.eyes)
        }
        .font(.system(size: 11, weight: .semibold))
        .labelStyle(CompactLabel())
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            padding().background(color)
        }
    }
}

struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon.font(.system(size: 9)); configuration.title }
    }
}
