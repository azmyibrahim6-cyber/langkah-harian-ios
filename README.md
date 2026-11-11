# LangkahKu iOS Native (SwiftUI + CoreMotion, Target iOS 15+)

Aplikasi penghitung langkah harian iOS native yang dirancang khusus agar kompatibel dengan **iPhone 7 Plus (iOS 15)** hingga iPhone terbaru.

## Fitur Utama

- **Sensor Koprosesor M10 (`CMPedometer`)**: Mengambil riwayat langkah 7 hari terakhir dan hitungan hari ini secara langsung dari chip gerak Apple, sehingga langkah tetap tercatat otomatis walau layar iPhone terkunci atau aplikasi ditutup.
- **Pembaruan Langsung & Koreksi Manual**: Mendukung live stream langkah (`startUpdates`), estimasi jarak hardware/stride, kalori terbakar, waktu aktif, streak target, grafik 7 hari, serta koreksi manual.
- **Tanpa Dependensi Pihak Ketiga**: Dibangun murni dengan SwiftUI, CoreMotion, dan XCTest dengan target minimum **iOS 15.0**.

## Cara Build & Pasang ke iPhone 7 Plus (dari Windows tanpa Mac)

Karena Xcode hanya berjalan di macOS, proyek ini sudah dilengkapi spesifikasi **XcodeGen** (`project.yml`) dan workflow **GitHub Actions** (`.github/workflows/build-ipa.yml`):

1. Upload folder `langkah-harian-ios` ke repository GitHub (publik atau privat):
   ```bash
   git init
   git add .
   git commit -m "Initial LangkahKu iOS project"
   git branch -M main
   git remote add origin https://github.com/<username>/<repo>.git
   git push -u origin main
   ```
2. Buka tab **Actions** di GitHub, tunggu workflow **Build iOS IPA (iOS 15+)** selesai (otomatis menjalankan unit test lalu menghasilkan file `LangkahKu-unsigned.ipa`).
3. Unduh artefak **LangkahKu-unsigned-ipa** di bagian bawah halaman hasil workflow dan ekstrak file `LangkahKu-unsigned.ipa`.
4. Pasang ke **iPhone 7 Plus** dari Windows menggunakan **Sideloadly** atau **AltStore**:
   - Sambungkan iPhone 7 Plus ke PC Windows via kabel USB (pastikan iTunes/Apple Devices terpasang dan pilih *Trust This Computer* di iPhone).
   - Buka Sideloadly, seret `LangkahKu-unsigned.ipa`, masukkan Apple ID Anda, lalu klik **Start**.
   - Setelah terpasang, buka **Settings > General > VPN & Device Management** di iPhone 7 Plus dan pilih **Trust** pada sertifikat Apple ID Anda.
   - *(Catatan Apple ID gratis: sertifikat sideload perlu di-refresh setiap 7 hari sekali).*

## Build Lokal di Mac (Jika Ada Mac)

```bash
brew install xcodegen
xcodegen generate
open LangkahKu.xcodeproj
```

Pilih perangkat **iPhone 7 Plus** atau simulator di Xcode, atur Signing Team dengan Apple ID Anda, lalu tekan **Run (Cmd+R)**.
