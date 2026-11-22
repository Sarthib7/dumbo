import Charts
import DumboKit
import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    Text(model.summaryWeek ? "This week" : "Today").font(.system(size: 30, weight: .bold))
                    Spacer()
                    Text(dateLabel).font(.footnote).foregroundStyle(Palette.muted)
                }
                Picker("", selection: $model.summaryWeek) {
                    Text("Day").tag(false)
                    Text("Week").tag(true)
                }
                .pickerStyle(.segmented)
                if model.summaryWeek { WeekView(week: model.week, goal: model.settings.dailyGoalMinutes) }
                else { TodayView(day: model.today, waterGoal: model.settings.waterGoal) }
            }
            .padding(20)
        }
        .background(Color.black)
    }

    var dateLabel: String {
        let f = DateFormatter()
        if model.summaryWeek {
            f.dateFormat = "d MMM"
            let start = Calendar.current.date(byAdding: .day, value: -6, to: model.now)!
            return "\(f.string(from: start)) – \(f.string(from: model.now))"
        }
        f.dateFormat = "EEE, d MMM"
        return f.string(from: model.now)
    }
}

struct EnergyRing: View {
    let value: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
            Circle().trim(from: 0, to: value / 100)
                .stroke(Palette.ember, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.ember2.opacity(0.6), radius: 6)
            HeartView(energy: value, pulse: false).padding(22)
        }
    }
}

struct TodayView: View {
    let day: DaySummary
    let waterGoal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Card {
                HStack(spacing: 16) {
                    EnergyRing(value: day.averageEnergy).frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 3) {
                        Caption("screen-on")
                        Text(formatMinutes(day.screenMinutes)).font(.system(size: 30, weight: .bold, design: .rounded))
                        (Text("avg session energy ").foregroundStyle(Palette.muted)
                         + Text("\(Int(day.averageEnergy))%").foregroundStyle(Palette.ember2).bold())
                            .font(.footnote)
                    }
                }
            }
            Card {
                Caption("sessions · \(day.sessions.count)")
                SessionTimeline(sessions: day.sessions, day: day.date).frame(height: 26)
                HStack {
                    Text("6a"); Spacer(); Text("12p"); Spacer(); Text("6p"); Spacer(); Text("12a")
                }
                .font(.system(size: 10)).foregroundStyle(Color(white: 0.4))
                HStack {
                    (Text("longest ") + Text(formatMinutes(day.longestMinutes)).bold().foregroundStyle(.white))
                    Spacer()
                    (Text("breaks ") + Text("\(day.promptsDone)/\(day.promptsShown)").bold().foregroundStyle(.white))
                }
                .font(.footnote).foregroundStyle(Palette.muted).padding(.top, 2)
            }
            HStack(spacing: 10) {
                habit("water", "\(day.glasses)", "/\(waterGoal)", Palette.water, Double(day.glasses) / Double(max(1, waterGoal)))
                habit("breaths", "\(day.breaths)", "", Palette.breath, Double(day.breaths) / 5)
                habit("eyes", "\(day.eyeBreaks)", "", Palette.eyes, Double(day.eyeBreaks) / 8)
            }
            Text(quip).font(.subheadline).foregroundStyle(Color(white: 0.85)).padding(.top, 4)
        }
    }

    var quip: AttributedString {
        let n = day.sessions.count
        var s = AttributedString(n == 0 ? "No screen sessions yet. Suspiciously healthy." : "You put the phone down ")
        if n > 0 {
            var b = AttributedString("\(n) times")
            b.font = .subheadline.bold()
            s += b + AttributedString(" on your own. Iconic.")
        }
        return s
    }

    func habit(_ title: String, _ value: String, _ suffix: String, _ color: Color, _ progress: Double) -> some View {
        Card {
            Caption(title)
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(suffix).font(.caption).foregroundStyle(Palette.muted)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: g.size.width * min(1, progress))
                }
            }
            .frame(height: 4)
        }
    }
}

struct SessionTimeline: View {
    let sessions: [Session]
    let day: Date

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06))
                ForEach(sessions) { s in
                    let x = position(s.start) * g.size.width
                    let w = max(3, Double(s.minutes) / (18 * 60) * g.size.width)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Palette.ember)
                        .opacity(0.45 + 0.55 * (1 - s.minEnergy / 100))
                        .frame(width: w, height: g.size.height - 8)
                        .offset(x: x)
                }
            }
        }
    }

    func position(_ date: Date) -> Double {
        let hours = date.timeIntervalSince(day) / 3600 - 6
        return max(0, min(1, hours / 18))
    }
}

struct WeekView: View {
    let week: WeekSummary
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Card {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Caption("daily average")
                        Text(formatMinutes(week.dailyAverage)).font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    if let c = week.changePercent {
                        Text("\(c <= 0 ? "↓" : "↑") \(abs(c))% vs last week").font(.footnote.bold())
                            .foregroundStyle(c <= 0 ? Palette.ember2 : Palette.muted)
                    }
                }
                Chart {
                    ForEach(Array(week.days.enumerated()), id: \.offset) { i, d in
                        BarMark(x: .value("Day", weekday(d.date) + "\(i)"), y: .value("Minutes", d.screenMinutes))
                            .foregroundStyle(LinearGradient(colors: [Palette.ember1, Palette.ember2], startPoint: .bottom, endPoint: .top))
                            .opacity(i == week.days.count - 1 ? 1 : 0.5)
                            .cornerRadius(6)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .chartXAxis {
                    AxisMarks { v in
                        AxisValueLabel { Text(String((v.as(String.self) ?? "").prefix(1))) }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 130)
            }
            HStack(spacing: 10) {
                stat("breaks", "\(Int(week.breakRate * 100))%", .white)
                stat("water", "\(week.glasses)", Palette.water)
                stat("goal", "\(week.daysUnderGoal)/7", Palette.ember2)
            }
            Card {
                Caption("when you scroll")
                Heatmap(week: week)
            }
            Text(week.insight).font(.subheadline.weight(.semibold)).padding(.top, 4)
        }
    }

    func weekday(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }

    func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        Card {
            Caption(title)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
        }
    }
}

struct Heatmap: View {
    let week: WeekSummary

    var body: some View {
        let peak = max(1, week.heatmap.flatMap { $0 }.max() ?? 1)
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Text("")
                ForEach(WeekSummary.heatmapBuckets, id: \.self) { Text($0) }
            }
            .font(.system(size: 9)).foregroundStyle(Color(white: 0.4))
            ForEach(Array(week.days.enumerated()), id: \.offset) { r, d in
                GridRow {
                    Text(d.date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)).foregroundStyle(Color(white: 0.4))
                    ForEach(0..<WeekSummary.heatmapBuckets.count, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Palette.ember1)
                            .opacity(0.08 + 0.92 * Double(week.heatmap[r][c]) / Double(peak))
                            .frame(height: 12)
                    }
                }
            }
        }
    }
}
