import Foundation
import Testing
import CodexBarCore

@Suite struct UsageMeterPresentationTests {
    private let now = Date(timeIntervalSince1970: 1000)
    private func meter(seconds: Double, used: Double = 36, minutes: Int? = 300, numeric: Bool = true) -> UsageMeterPresentation {
        UsageMeterPresentation(window: UsageWindow(label: "5h", usedPercent: used, windowMinutes: minutes, resetsAt: now.addingTimeInterval(seconds)), numericCountdown: numeric, now: now)
    }
    @Test func numericFormatCountsSecondsAndKeepsHoursBeyondOneDay() {
        #expect(meter(seconds: 10799).resetText == "2:59:59")
        #expect(meter(seconds: 90061, minutes: 10080).resetText == "25:01:01")
        #expect(meter(seconds: 0.1).resetText == "0:00:01")
        #expect(meter(seconds: -5).resetText == "0:00:00")
    }
    @Test func weeklyCountdownUsesDaysHoursAndMinutes() {
        func weekly(_ seconds: Double) -> String {
            UsageMeterPresentation(window: UsageWindow(label: "7D", usedPercent: 36, windowMinutes: 10080, resetsAt: now.addingTimeInterval(seconds)), numericCountdown: true, now: now, dayCountdown: true).resetText
        }
        #expect(weekly(604799) == "6:23:59")
        #expect(weekly(604799.9) == "6:23:59")
        #expect(weekly(90061) == "1:01:01")
        #expect(weekly(86399) == "0:23:59")
        #expect(weekly(3600) == "0:01:00")
        #expect(weekly(59) == "0:00:00")
        #expect(weekly(-1) == "0:00:00")
    }
    @Test func textFormatUsesReadableDurations() {
        #expect(meter(seconds: 7200, numeric: false).resetText == "2小时后重置")
        #expect(meter(seconds: 10799, numeric: false).resetText == "2小时59分后重置")
        #expect(meter(seconds: 90061, numeric: false).resetText == "1天1小时后重置")
        #expect(meter(seconds: 0, numeric: false).resetText == "即将重置")
    }
    @Test func consumptionAndElapsedTimeShareTheSameScale() {
        let value = meter(seconds: 7200)
        #expect(value.usedFraction == 0.36)
        #expect(value.elapsedFraction == 0.6)
        #expect(value.remainingText == "剩余 64%")
    }
    @Test func fractionsClampBeforeAndAfterTheCycle() {
        #expect(meter(seconds: 20000, used: -10).usedFraction == 0)
        #expect(meter(seconds: 20000).elapsedFraction == 0)
        #expect(meter(seconds: -1, used: 110).usedFraction == 1)
        #expect(meter(seconds: -1).elapsedFraction == 1)
    }
    @Test func missingDataDoesNotInventATimeCursor() {
        let absent = UsageMeterPresentation(window: nil, numericCountdown: true, now: now)
        #expect(absent.usedFraction == nil)
        #expect(absent.elapsedFraction == nil)
        #expect(absent.remainingText == "剩余 --")
        #expect(absent.resetText == "重置时间 --")
        #expect(meter(seconds: 7200, minutes: nil).elapsedFraction == nil)
        #expect(meter(seconds: 7200, minutes: 0).elapsedFraction == nil)
    }
    @Test func advancingTimeUpdatesCountdownAndCursorTogether() {
        let window = UsageWindow(label: "5h", usedPercent: 36, windowMinutes: 300, resetsAt: now.addingTimeInterval(7200))
        let updated = UsageMeterPresentation(window: window, numericCountdown: true, now: now.addingTimeInterval(1))
        #expect(updated.resetText == "1:59:59")
        #expect(updated.elapsedFraction! > 0.6)
        #expect(updated.usedFraction == 0.36)
    }
}
