import XCTest
@testable import DumboKit

final class EngineTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func minute(_ m: Int) -> Date { t0.addingTimeInterval(Double(m) * 60) }

    func testDrainsToZeroOverModeLength() {
        var d = DumboData()
        for m in 1...45 { DumboEngine.recordUse(at: minute(m), in: &d) }
        XCTAssertEqual(d.sessions.count, 1)
        XCTAssertEqual(d.sessions[0].minutes, 45)
        XCTAssertEqual(d.sessions[0].energy, 0, accuracy: 0.001)
    }

    func testStrictDrainsFaster() {
        var d = DumboData()
        d.settings.mode = .strict
        for m in 1...10 { DumboEngine.recordUse(at: minute(m), in: &d) }
        XCTAssertEqual(d.sessions[0].energy, 60, accuracy: 0.001)
    }

    func testShortGlanceAwayKeepsSession() {
        var d = DumboData()
        DumboEngine.recordUse(at: minute(1), in: &d)
        DumboEngine.recordUse(at: minute(4), in: &d)
        XCTAssertEqual(d.sessions.count, 1)
    }

    func testPhoneDownFiveMinutesStartsFreshSession() {
        var d = DumboData()
        for m in 1...20 { DumboEngine.recordUse(at: minute(m), in: &d) }
        DumboEngine.recordUse(at: minute(27), in: &d)
        XCTAssertEqual(d.sessions.count, 2)
        XCTAssertEqual(d.sessions[1].minutes, 1)
        XCTAssertGreaterThan(d.sessions[1].energy, 97)
    }

    func testPromptsRotateEveryTenMinutes() {
        var d = DumboData()
        var due: [PromptKind] = []
        for m in 1...30 {
            if let k = DumboEngine.recordUse(at: minute(m), in: &d) {
                due.append(k)
                DumboEngine.show(k, at: minute(m), in: &d)
                DumboEngine.skip(at: minute(m), in: &d)
            }
        }
        XCTAssertEqual(due, [.eyes, .breathe, .sip])
    }

    func testNoNewPromptWhileOneIsActive() {
        var d = DumboData()
        for m in 1...10 { DumboEngine.recordUse(at: minute(m), in: &d) }
        DumboEngine.show(.eyes, at: minute(10), in: &d)
        XCTAssertNil(DumboEngine.recordUse(minutes: 10, at: minute(11), in: &d))
    }

    func testUnansweredPromptExpires() {
        var d = DumboData()
        DumboEngine.recordUse(at: minute(1), in: &d)
        DumboEngine.show(.eyes, at: minute(1), in: &d)
        DumboEngine.recordUse(at: minute(4), in: &d)
        XCTAssertNil(d.activePrompt)
    }

    func testEmptyPromptAtZero() {
        var d = DumboData()
        d.settings.mode = .strict
        var last: PromptKind?
        for m in 1...30 {
            if let k = DumboEngine.recordUse(at: minute(m), in: &d) { last = k }
        }
        XCTAssertEqual(last, .empty)
    }

    func testCompleteBoostsAndCaps() {
        var d = DumboData()
        for m in 1...10 { DumboEngine.recordUse(at: minute(m), in: &d) }
        let before = d.sessions[0].energy
        DumboEngine.show(.breathe, at: minute(10), in: &d)
        DumboEngine.complete(.breathe, at: minute(10), in: &d)
        XCTAssertEqual(d.sessions[0].energy, min(100, before + 20), accuracy: 0.001)
        XCTAssertNil(d.activePrompt)
        XCTAssertEqual(d.prompts.last?.outcome, .done)
        DumboEngine.complete(.eyes, at: minute(10), in: &d)
        XCTAssertEqual(d.sessions[0].energy, 100, accuracy: 0.001)
    }

    func testGlassAnswersSipPrompt() {
        var d = DumboData()
        DumboEngine.recordUse(at: minute(1), in: &d)
        DumboEngine.show(.sip, at: minute(1), in: &d)
        DumboEngine.logGlass(at: minute(1), in: &d)
        XCTAssertEqual(d.water.count, 1)
        XCTAssertNil(d.activePrompt)
        XCTAssertEqual(d.prompts.last?.outcome, .done)
    }

    func testCursorConvertsCumulativeThresholds() {
        var d = DumboData()
        XCTAssertEqual(DumboEngine.minutesSinceCursor(threshold: 1, at: minute(1), in: &d), 1)
        XCTAssertEqual(DumboEngine.minutesSinceCursor(threshold: 2, at: minute(2), in: &d), 1)
        XCTAssertEqual(DumboEngine.minutesSinceCursor(threshold: 5, at: minute(5), in: &d), 3)
        XCTAssertEqual(DumboEngine.minutesSinceCursor(threshold: 4, at: minute(6), in: &d), 0)
    }
}

final class SummaryTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testDaySummary() {
        var d = DumboData()
        for m in 1...30 { DumboEngine.recordUse(at: date(22, 9, m), in: &d) }
        for m in 1...12 { DumboEngine.recordUse(at: date(22, 20, m), in: &d) }
        DumboEngine.logGlass(at: date(22, 10), in: &d)
        DumboEngine.complete(.breathe, at: date(22, 20, 5), in: &d)
        let s = Summarizer.day(date(22, 12), data: d, calendar: cal)
        XCTAssertEqual(s.sessions.count, 2)
        XCTAssertEqual(s.screenMinutes, 42)
        XCTAssertEqual(s.longestMinutes, 30)
        XCTAssertEqual(s.glasses, 1)
        XCTAssertEqual(s.breaths, 1)
    }

    func testWeekSummaryComparesToLastWeek() {
        var d = DumboData()
        for m in 1...60 { DumboEngine.recordUse(at: date(10, 21, m % 60 == 0 ? 59 : m), in: &d) }
        for m in 1...30 { DumboEngine.recordUse(at: date(18, 22, m), in: &d) }
        let w = Summarizer.week(endingOn: date(22, 12), data: d, calendar: cal)
        XCTAssertEqual(w.days.count, 7)
        XCTAssertEqual(w.dailyAverage, 30 / 7)
        XCTAssertNotNil(w.changePercent)
        XCTAssertEqual(w.heatmap[2][5], 30)
        XCTAssertTrue(w.insight.contains("nights"))
    }
}
