# 🖱️ MouseBack

Aplikasi native macOS kecil, ringan, dan efisien untuk mengaktifkan fungsi navigasi tombol samping (**Kembali / Back** & **Maju / Forward**) pada mouse Bluetooth UGREEN dan mouse lainnya.

---

## ✨ Fitur & Keunggulan

- **Dukungan Khusus Mouse UGREEN BLE**:
  Mouse Bluetooth UGREEN (misal: UGREEN BLE Mouse VID `0x32C2` / PID `0x0012`) dapat mengirimkan sinyal panah keyboard internal (`Key 123` = Panah Kiri, `Key 124` = Panah Kanan). MouseBack menerjemahkannya menjadi navigasi browser hanya jika ID pengirim event cocok dengan perangkat UGREEN yang terdeteksi:
  - **Tombol Belakang** (`Key 123`): **Kembali (`Cmd + [`)**
  - **Tombol Depan** (`Key 124`): **Maju (`Cmd + ]`)**
- **Panah Keyboard**: Panah dari keyboard fisik, kombinasi Shift/Option/Control/Command, dan panah tanpa ID pengirim UGREEN tetap berfungsi sebagai panah. Jika log mencatat `Ugreen: 0`, MouseBack tidak menerjemahkan sinyal panah menjadi navigasi; tombol samping yang mengirim event mouse standar tetap berfungsi.
- **Dukungan Mouse Standar Lainnya**: Mendukung tombol mouse standar 3, 4, dan 5 (`otherMouseDown`).
- **Kompatibilitas Penuh**: Berfungsi di BrowserOS Neo, Google Chrome, Safari, Arc, Brave, Microsoft Edge, Firefox, Finder, dan aplikasi macOS lainnya.
- **Menu Bar Utility**: Berjalan di status bar atas Mac tanpa memenuhi Dock atau app switcher.
- **Tukar Tombol (Swap)**: Opsi instan jika Anda ingin membalik fungsi tombol depan dan belakang.
- **Launch at Login**: Opsi otomatis aktif di latar belakang setiap kali Mac dinyalakan.
- **Keamanan Stabil**: Ditandatangani dengan *Designated Requirement* stabil (`com.dany.mouseback`) sehingga izin Aksesibilitas tidak ter-reset saat aplikasi dibuka-tutup.
- **Jendela Monitor Sinyal (HUD)**: Panel opsional di Menu Bar untuk memantau sinyal hardware mouse secara langsung (*real-time*).

---

## 🚀 Cara Menjalankan

### 1. Buka Aplikasi
Cukup klik ganda **`MouseBack.app`** di folder ini atau jalankan melalui Terminal:
```bash
open MouseBack.app
```

*(Opsional: Anda bisa memindahkan `MouseBack.app` ke folder `/Applications` Mac Anda).*

### 2. Izin Aksesibilitas (Hanya Sekali di Awal)
1. Buka **System Settings** > **Privacy & Security** > **Accessibility**.
2. Pastikan sakelar **MouseBack** dalam posisi **ON**.
3. Status di Menu Bar akan langsung menampilkan **🟢 MouseBack: Aktif**.

---

## ⚙️ Menu Bar

Klik ikon mouse di status bar atas layar Mac Anda:
- **Status**: Menampilkan status saat ini (*🟢 Aktif*, *⚪ Nonaktif*, atau *🟡 Butuh Izin Aksesibilitas*).
- **Aktifkan MouseBack**: Toggle On/Off fungsi penangkapan tombol.
- **Tukar Tombol Samping (Swap Back / Forward)**: Membalik arah tombol.
- **Tampilkan Jendela Monitor Sinyal (HUD)**: Membuka panel transparan di pojok layar untuk melihat kode sinyal mouse secara langsung.
- **Tampilkan Notifikasi Pop-up saat Tombol Ditekan**: Memunculkan banner pop-up saat tombol samping diklik.
- **Buka Otomatis saat Login**: Menjadikan aplikasi otomatis berjalan saat Mac dinyalakan.
- **Buka Pengaturan Aksesibilitas...**: Pintasan langsung ke pengaturan sistem macOS.
- **Buka File Log (/tmp/mouseback.log)**: Membuka log aktivitas sistem.
- **Keluar**: Menutup aplikasi sepenuhnya.

---

## 🛠️ Kompilasi Ulang (Build)

Jika Anda ingin mengubah kode di folder `Sources/`, cukup jalankan:
```bash
./build.sh
```
Skrip ini akan mengompilasi kode Swift dan menghasilkan bundle `MouseBack.app` yang ditandatangani.

Untuk memeriksa aturan sumber panah tanpa mouse atau izin Aksesibilitas:
```bash
swiftc -parse-as-library Sources/HUDWindow.swift Sources/EventTapManager.swift Tests/ArrowSourceTests.swift -o /tmp/mouseback-arrow-tests && /tmp/mouseback-arrow-tests
```
