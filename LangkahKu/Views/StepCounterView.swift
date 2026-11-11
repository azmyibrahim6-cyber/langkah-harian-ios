import SwiftUI
import UIKit

struct StepCounterView: View {
    @ObservedObject var store: PedometerStore
    @State private var showingSettings = false

    private let idLocale = Locale(identifier: "id_ID")

    private var formattedToday: String {
        let df = DateFormatter()
        df.locale = idLocale
        df.dateFormat = "EEEE, d MMMM"
        return df.string(from: Date()).capitalized
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    headerView

                    statusBannerView

                    heroRingCard

                    metricsGridView

                    weeklyChartCard

                    manualAdjustCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showingSettings) {
            SettingsSheetView(store: store, isPresented: $showingSettings)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LangkahKu")
                    .font(.title2.bold())
                Text(formattedToday)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                store.refreshAuthorizationAndData()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityLabel("Sinkronkan langkah")

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityLabel("Pengaturan")
        }
    }

    @ViewBuilder
    private var statusBannerView: some View {
        switch store.status {
        case .needsPermission:
            bannerCard(
                title: "Izin Aktivitas Gerak Diperlukan",
                message: "Izinkan akses Motion & Fitness agar iPhone 7 Plus mencatat langkah Anda secara otomatis di latar belakang.",
                buttonTitle: "Izinkan Sensor Langkah"
            ) {
                store.requestPermissionAndStart()
            }
        case .denied:
            bannerCard(
                title: "Izin Sensor Ditolak",
                message: "Buka Pengaturan iPhone > Privasi > Motion & Fitness lalu aktifkan izin untuk LangkahKu.",
                buttonTitle: "Buka Pengaturan iPhone"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .unavailable:
            bannerCard(
                title: "Sensor Hardware Tidak Tersedia",
                message: "Mode simulator atau perangkat tanpa pedometer terdeteksi. Gunakan tombol Tambah Manual di bawah untuk uji coba.",
                buttonTitle: nil,
                action: nil
            )
        case .active, .paused:
            EmptyView()
        }
    }

    private func bannerCard(
        title: String,
        message: String,
        buttonTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            if let buttonTitle = buttonTitle, let action = action {
                Button(buttonTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var heroRingCard: some View {
        let goal = max(1, store.settings.dailyGoal)
        let steps = store.todaySteps
        let progress = min(1.0, Double(steps) / Double(goal))
        let percent = Int((Double(steps) / Double(goal) * 100.0).rounded())

        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.isLiveUpdating ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(statusBadgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(store.isLiveUpdating ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 16)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: progress)

                VStack(spacing: 4) {
                    Text(formatInt(steps))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    Text("dari \(formatInt(goal)) langkah")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(percent >= 100 ? "Target tercapai (\(percent)%)" : "\(percent)% tercapai")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.14))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }
            }
            .frame(width: 210, height: 210)

            Button {
                store.toggleLiveUpdates()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: store.isLiveUpdating ? "pause.fill" : "play.fill")
                    Text(store.isLiveUpdating ? "Jeda Pembaruan Langsung" : "Mulai Hitung Langsung")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: store.isLiveUpdating
                            ? [Color.orange, Color.red.opacity(0.85)]
                            : [Color.blue, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var statusBadgeText: String {
        switch store.status {
        case .active: return "Sensor M10 Aktif (Latar Belakang)"
        case .paused: return "Pembaruan Dijeda"
        case .needsPermission: return "Menunggu Izin Sensor"
        case .denied: return "Izin Ditolak"
        case .unavailable: return "Mode Manual / Simulator"
        }
    }

    private var metricsGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            metricCard(
                icon: "location.fill",
                color: .blue,
                title: "Perkiraan Jarak",
                value: String(format: "%.2f km", store.todayDistanceKm).replacingOccurrences(of: ".", with: ",")
            )
            metricCard(
                icon: "flame.fill",
                color: .orange,
                title: "Kalori Terbakar",
                value: "\(Int(store.todayCaloriesKcal.rounded())) kkal"
            )
            metricCard(
                icon: "clock.fill",
                color: .green,
                title: "Waktu Aktif",
                value: StepMetrics.formatDuration(minutes: store.todayActiveMinutes)
            )
            metricCard(
                icon: "checkmark.circle.fill",
                color: .purple,
                title: "Streak Target",
                value: "\(store.streakDays) hari"
            )
        }
    }

    private func metricCard(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weeklyChartCard: some View {
        let days = store.weeklyDays
        let avg = days.isEmpty ? 0 : days.reduce(0) { $0 + $1.totalSteps } / days.count
        let maxSteps = max(store.settings.dailyGoal, max(100, days.map(\.totalSteps).max() ?? 100))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Riwayat 7 Hari Terakhir")
                    .font(.subheadline.bold())
                Spacer()
                Text("Rata-rata \(formatInt(avg)) / hari")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    let ratio = day.totalSteps > 0
                        ? max(0.08, Double(day.totalSteps) / Double(maxSteps))
                        : 0.05
                    let barColor: Color = day.isToday
                        ? .blue
                        : (day.totalSteps >= store.settings.dailyGoal ? .green : Color.secondary.opacity(0.35))

                    VStack(spacing: 5) {
                        Text(day.totalSteps >= 1000
                            ? String(format: "%.1fk", Double(day.totalSteps) / 1000.0)
                            : "\(day.totalSteps)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        ZStack(alignment: .bottom) {
                            Color.clear.frame(height: 92)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(barColor)
                                .frame(width: 22, height: CGFloat(92.0 * ratio))
                        }

                        Text(day.shortLabel)
                            .font(.caption2.weight(day.isToday ? .bold : .medium))
                            .foregroundColor(day.isToday ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var manualAdjustCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tambah / Koreksi Manual")
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                ForEach([10, 100, 500, -10], id: \.self) { delta in
                    Button {
                        store.addManualSteps(delta)
                    } label: {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatInt(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.locale = idLocale
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct SettingsSheetView: View {
    @ObservedObject var store: PedometerStore
    @Binding var isPresented: Bool

    @State private var goalText: String = ""
    @State private var strideText: String = ""
    @State private var weightText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Target & Profil")) {
                    HStack {
                        Text("Target Langkah")
                        Spacer()
                        TextField("8000", text: $goalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Panjang Langkah (cm)")
                        Spacer()
                        TextField("72", text: $strideText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Berat Badan (kg)")
                        Spacer()
                        TextField("65", text: $weightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.resetToday()
                        isPresented = false
                    } label: {
                        Text("Reset Langkah Hari Ini")
                    }
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        let updated = UserSettings(
                            dailyGoal: Int(goalText) ?? store.settings.dailyGoal,
                            strideCm: Int(strideText) ?? store.settings.strideCm,
                            weightKg: Int(weightText) ?? store.settings.weightKg
                        )
                        store.updateSettings(updated)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                goalText = "\(store.settings.dailyGoal)"
                strideText = "\(store.settings.strideCm)"
                weightText = "\(store.settings.weightKg)"
            }
        }
        .navigationViewStyle(.stack)
    }
}
