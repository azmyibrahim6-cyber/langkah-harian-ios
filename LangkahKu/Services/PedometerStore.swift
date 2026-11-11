import Combine
import CoreMotion
import Foundation

final class PedometerStore: ObservableObject {

    enum TrackingStatus: Equatable {
        case unavailable
        case needsPermission
        case denied
        case active
        case paused
    }

    @Published private(set) var todayDateKey: String = ""
    @Published private(set) var todayHardwareSteps: Int = 0
    @Published private(set) var todayMeasuredMeters: Double? = nil
    @Published private(set) var weeklyDays: [DayRecord] = []
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var status: TrackingStatus = .paused
    @Published private(set) var isLiveUpdating: Bool = false
    @Published var settings: UserSettings

    private let pedometer = CMPedometer()
    private let defaults: UserDefaults
    private let calendar = Calendar.current

    private var cachedHardwareByDate: [String: Int] = [:]
    private var manualOffsetByDate: [String: Int] = [:]
    private var distanceByDate: [String: Double] = [:]
    private var timer: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.loadSettings(from: defaults)
        self.cachedHardwareByDate = Self.loadIntMap(forKey: Keys.hardwareCache, from: defaults)
        self.manualOffsetByDate = Self.loadIntMap(forKey: Keys.manualOffsets, from: defaults)
        self.todayDateKey = DateKeyHelper.key(from: Date(), calendar: calendar)

        rebuildState()
        refreshAuthorizationAndData()

        // Cek pergantian tanggal otomatis setiap 30 detik saat aplikasi aktif
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkDayRollover()
            }
    }

    var todaySteps: Int {
        let offset = manualOffsetByDate[todayDateKey] ?? 0
        return max(0, todayHardwareSteps + offset)
    }

    var todayDistanceKm: Double {
        let offset = manualOffsetByDate[todayDateKey] ?? 0
        // Pakai jarak sensor hardware hanya jika belum ada koreksi manual besar
        let meters = offset == 0 ? todayMeasuredMeters : nil
        return StepMetrics.distanceKm(
            steps: todaySteps,
            strideCm: settings.strideCm,
            measuredMeters: meters
        )
    }

    var todayCaloriesKcal: Double {
        StepMetrics.caloriesKcal(distanceKm: todayDistanceKm, weightKg: settings.weightKg)
    }

    var todayActiveMinutes: Int {
        StepMetrics.estimatedActiveMinutes(steps: todaySteps)
    }

    func refreshAuthorizationAndData() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = .unavailable
            isLiveUpdating = false
            rebuildState()
            return
        }

        switch CMPedometer.authorizationStatus() {
        case .denied, .restricted:
            status = .denied
            isLiveUpdating = false
            rebuildState()
        case .notDetermined:
            status = .needsPermission
            rebuildState()
        case .authorized:
            queryLastSevenDays()
            startLiveUpdates()
        @unknown default:
            status = .needsPermission
            rebuildState()
        }
    }

    func requestPermissionAndStart() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = .unavailable
            return
        }
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        // Memanggil queryPedometerData saat notDetermined akan memunculkan dialog izin iOS
        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if error != nil {
                    let auth = CMPedometer.authorizationStatus()
                    self.status = (auth == .denied || auth == .restricted) ? .denied : .needsPermission
                    return
                }
                if let steps = data?.numberOfSteps.intValue {
                    self.cachedHardwareByDate[self.todayDateKey] = steps
                    self.todayHardwareSteps = steps
                    self.todayMeasuredMeters = data?.distance?.doubleValue
                    self.saveIntMap(self.cachedHardwareByDate, forKey: Keys.hardwareCache)
                }
                self.queryLastSevenDays()
                self.startLiveUpdates()
            }
        }
    }

    func toggleLiveUpdates() {
        if isLiveUpdating {
            stopLiveUpdates()
        } else {
            refreshAuthorizationAndData()
            if status == .needsPermission {
                requestPermissionAndStart()
            } else if status == .paused {
                startLiveUpdates()
            }
        }
    }

    func startLiveUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = .unavailable
            isLiveUpdating = false
            return
        }

        pedometer.stopUpdates()
        let startOfDay = calendar.startOfDay(for: Date())
        isLiveUpdating = true
        status = .active

        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if error != nil {
                    let auth = CMPedometer.authorizationStatus()
                    if auth == .denied || auth == .restricted {
                        self.status = .denied
                        self.isLiveUpdating = false
                    }
                    return
                }
                guard let data = data else { return }
                let nowKey = DateKeyHelper.key(from: Date(), calendar: self.calendar)
                if nowKey != self.todayDateKey {
                    self.todayDateKey = nowKey
                    self.queryLastSevenDays()
                    self.startLiveUpdates()
                    return
                }
                let steps = data.numberOfSteps.intValue
                self.todayHardwareSteps = steps
                self.todayMeasuredMeters = data.distance?.doubleValue
                self.cachedHardwareByDate[nowKey] = steps
                self.saveIntMap(self.cachedHardwareByDate, forKey: Keys.hardwareCache)
                self.rebuildState()
            }
        }
    }

    func stopLiveUpdates() {
        pedometer.stopUpdates()
        isLiveUpdating = false
        if CMPedometer.isStepCountingAvailable() && CMPedometer.authorizationStatus() == .authorized {
            status = .paused
        }
    }

    func addManualSteps(_ delta: Int) {
        let currentOffset = manualOffsetByDate[todayDateKey] ?? 0
        let nextTotal = max(0, todayHardwareSteps + currentOffset + delta)
        manualOffsetByDate[todayDateKey] = nextTotal - todayHardwareSteps
        saveIntMap(manualOffsetByDate, forKey: Keys.manualOffsets)
        rebuildState()
    }

    func resetToday() {
        manualOffsetByDate[todayDateKey] = -todayHardwareSteps
        saveIntMap(manualOffsetByDate, forKey: Keys.manualOffsets)
        rebuildState()
    }

    func updateSettings(_ newSettings: UserSettings) {
        settings = newSettings.sanitized()
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: Keys.settings)
        }
        rebuildState()
    }

    private func checkDayRollover() {
        let nowKey = DateKeyHelper.key(from: Date(), calendar: calendar)
        guard nowKey != todayDateKey else { return }
        todayDateKey = nowKey
        todayHardwareSteps = 0
        todayMeasuredMeters = nil
        refreshAuthorizationAndData()
    }

    private func queryLastSevenDays() {
        let now = Date()
        let dates = DateKeyHelper.lastSevenDays(endingAt: now, calendar: calendar)

        for date in dates {
            let start = calendar.startOfDay(for: date)
            let isToday = calendar.isDateInToday(date)
            let end = isToday ? now : (calendar.date(byAdding: .day, value: 1, to: start) ?? now)
            let key = DateKeyHelper.key(from: start, calendar: calendar)

            pedometer.queryPedometerData(from: start, to: end) { [weak self] data, error in
                DispatchQueue.main.async {
                    guard let self = self, error == nil, let data = data else { return }
                    let steps = data.numberOfSteps.intValue
                    self.cachedHardwareByDate[key] = steps
                    if let meters = data.distance?.doubleValue {
                        self.distanceByDate[key] = meters
                        if isToday {
                            self.todayMeasuredMeters = meters
                        }
                    }
                    if isToday {
                        self.todayHardwareSteps = steps
                    }
                    self.saveIntMap(self.cachedHardwareByDate, forKey: Keys.hardwareCache)
                    self.rebuildState()
                }
            }
        }
    }

    private func rebuildState() {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        todayDateKey = DateKeyHelper.key(from: todayStart, calendar: calendar)
        let sevenDates = DateKeyHelper.lastSevenDays(endingAt: now, calendar: calendar)

        var records: [DayRecord] = []
        for date in sevenDates {
            let key = DateKeyHelper.key(from: date, calendar: calendar)
            let isToday = key == todayDateKey
            let hw = isToday ? max(todayHardwareSteps, cachedHardwareByDate[key] ?? 0) : (cachedHardwareByDate[key] ?? 0)
            let manual = manualOffsetByDate[key] ?? 0
            records.append(
                DayRecord(
                    dateKey: key,
                    shortLabel: DateKeyHelper.shortDayLabel(for: date, isToday: isToday),
                    hardwareSteps: hw,
                    manualOffset: manual,
                    distanceMeters: distanceByDate[key],
                    isToday: isToday
                )
            )
        }
        weeklyDays = records

        var combinedMap: [String: Int] = [:]
        let allKeys = Set(cachedHardwareByDate.keys).union(manualOffsetByDate.keys)
        for key in allKeys {
            let hw = key == todayDateKey ? max(todayHardwareSteps, cachedHardwareByDate[key] ?? 0) : (cachedHardwareByDate[key] ?? 0)
            let manual = manualOffsetByDate[key] ?? 0
            combinedMap[key] = max(0, hw + manual)
        }
        streakDays = StepMetrics.calculateStreak(
            stepsByDate: combinedMap,
            dailyGoal: settings.dailyGoal,
            today: now,
            calendar: calendar
        )
    }

    private func saveIntMap(_ map: [String: Int], forKey key: String) {
        defaults.set(map, forKey: key)
    }

    private static func loadIntMap(forKey key: String, from defaults: UserDefaults) -> [String: Int] {
        (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private static func loadSettings(from defaults: UserDefaults) -> UserSettings {
        guard let data = defaults.data(forKey: Keys.settings),
              let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings()
        }
        return decoded.sanitized()
    }

    private enum Keys {
        static let settings = "langkahku_ios_settings"
        static let hardwareCache = "langkahku_ios_hw_cache"
        static let manualOffsets = "langkahku_ios_manual_offsets"
    }
}
