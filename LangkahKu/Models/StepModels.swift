import Foundation

struct UserSettings: Codable, Equatable {
    var dailyGoal: Int = 8000
    var strideCm: Int = 72
    var weightKg: Int = 65

    func sanitized() -> UserSettings {
        UserSettings(
            dailyGoal: min(100_000, max(500, dailyGoal)),
            strideCm: min(150, max(30, strideCm)),
            weightKg: min(250, max(25, weightKg))
        )
    }
}

struct DayRecord: Identifiable, Equatable {
    var id: String { dateKey }
    let dateKey: String
    let shortLabel: String
    let hardwareSteps: Int
    let manualOffset: Int
    let distanceMeters: Double?
    let isToday: Bool

    var totalSteps: Int {
        max(0, hardwareSteps + manualOffset)
    }
}

enum DateKeyHelper {
    private static let shortDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEE"
        return df
    }()

    static func key(from date: Date, calendar: Calendar = .current) -> String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }

    static func shortDayLabel(for date: Date, isToday: Bool) -> String {
        if isToday { return "Kini" }
        return shortDayFormatter.string(from: date)
    }

    static func lastSevenDays(endingAt today: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: today)
        return (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }
}

enum StepMetrics {
    static func distanceKm(
        steps: Int,
        strideCm: Int,
        measuredMeters: Double? = nil
    ) -> Double {
        if let meters = measuredMeters, meters > 0 {
            return meters / 1000.0
        }
        let safeSteps = max(0, steps)
        let safeStride = min(150, max(30, strideCm))
        return Double(safeSteps * safeStride) / 100_000.0
    }

    static func caloriesKcal(distanceKm: Double, weightKg: Int) -> Double {
        let safeDist = max(0.0, distanceKm)
        let safeWeight = min(250, max(25, weightKg))
        return safeDist * Double(safeWeight) * 0.75
    }

    static func estimatedActiveMinutes(steps: Int) -> Int {
        // Rata-rata ~105 langkah per menit jalan santai-sedang
        max(0, Int((Double(max(0, steps)) / 105.0).rounded()))
    }

    static func formatDuration(minutes: Int) -> String {
        let safeMins = max(0, minutes)
        if safeMins < 60 {
            return "\(safeMins) mnt"
        }
        let hours = safeMins / 60
        let rem = safeMins % 60
        return rem > 0 ? "\(hours)j \(rem)m" : "\(hours) jam"
    }

    static func calculateStreak(
        stepsByDate: [String: Int],
        dailyGoal: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let goal = max(1, dailyGoal)
        let start = calendar.startOfDay(for: today)
        let todayKey = DateKeyHelper.key(from: start, calendar: calendar)
        let todaySteps = stepsByDate[todayKey] ?? 0
        var offset = todaySteps >= goal ? 0 : -1
        var streak = 0

        while offset > -3650 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { break }
            let key = DateKeyHelper.key(from: date, calendar: calendar)
            let steps = stepsByDate[key] ?? 0
            if steps >= goal {
                streak += 1
                offset -= 1
            } else {
                break
            }
        }
        return streak
    }
}
