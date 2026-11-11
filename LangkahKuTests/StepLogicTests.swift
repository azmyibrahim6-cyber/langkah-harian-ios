import XCTest
@testable import LangkahKu

final class StepLogicTests: XCTestCase {

    func testMetricsUseMeasuredMetersWhenAvailableAndFallbackToStride() {
        let estimated = StepMetrics.distanceKm(steps: 1000, strideCm: 70, measuredMeters: nil)
        XCTAssertEqual(estimated, 0.7, accuracy: 0.0001)

        let measured = StepMetrics.distanceKm(steps: 1000, strideCm: 70, measuredMeters: 850.0)
        XCTAssertEqual(measured, 0.85, accuracy: 0.0001)

        let kcal = StepMetrics.caloriesKcal(distanceKm: 1.0, weightKg: 60)
        XCTAssertEqual(kcal, 45.0, accuracy: 0.01)

        XCTAssertEqual(StepMetrics.formatDuration(minutes: 45), "45 mnt")
        XCTAssertEqual(StepMetrics.formatDuration(minutes: 65), "1j 5m")
    }

    func testSettingsSanitizationAndDayRecordNeverGoNegative() {
        let raw = UserSettings(dailyGoal: 10, strideCm: 5, weightKg: 999)
        let clean = raw.sanitized()
        XCTAssertEqual(clean.dailyGoal, 500)
        XCTAssertEqual(clean.strideCm, 30)
        XCTAssertEqual(clean.weightKg, 250)

        let record = DayRecord(
            dateKey: "2026-11-11",
            shortLabel: "Kini",
            hardwareSteps: 300,
            manualOffset: -500,
            distanceMeters: nil,
            isToday: true
        )
        XCTAssertEqual(record.totalSteps, 0)
    }

    func testStreakCountsConsecutiveDaysAndSevenDayWindowLength() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11))!

        let dates = DateKeyHelper.lastSevenDays(endingAt: today, calendar: calendar)
        XCTAssertEqual(dates.count, 7)

        let map: [String: Int] = [
            "2026-11-08": 7500,
            "2026-11-09": 8100,
            "2026-11-10": 8400,
            "2026-11-11": 2000
        ]
        XCTAssertEqual(
            StepMetrics.calculateStreak(stepsByDate: map, dailyGoal: 8000, today: today, calendar: calendar),
            2
        )

        var mapWithToday = map
        mapWithToday["2026-11-11"] = 8050
        XCTAssertEqual(
            StepMetrics.calculateStreak(stepsByDate: mapWithToday, dailyGoal: 8000, today: today, calendar: calendar),
            3
        )
    }
}
