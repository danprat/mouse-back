# 🖱️ MouseBack

Aplikasi native macOS kecil, ringan, dan efisien untuk mengaktifkan fungsi tombol samping (**Back** & **Forward**) pada mouse Bluetooth Ugreen dan mouse sejenis lainnya.

---

## ✨ Fitur Utama

- **Navigasi Cepat**: Menerjemahkan tombol samping mouse menjadi perintah **Kembali (`Cmd + [`)** dan **Maju (`Cmd + ]`)**.
- **Kompatibilitas Luas**: Bekerja otomatis di Safari, Google Chrome, Arc, Brave, Microsoft Edge, Firefox, Finder, dan berbagai aplikasi macOS lainnya.
- **Menu Bar Utility**: Berjalan di status bar atas (tanpa memenuhi Dock atau app switcher).
- **Tukar Tombol (Swap)**: Opsi fleksibel jika posisi tombol samping fisik pada mouse Anda terbalik.
- **Launch at Login**: Dapat diatur otomatis aktif setiap kali Mac dinyalakan.
- **Ringan & Hemat Daya**: Dibuat murni dengan Swift dan CoreGraphics tanpa framework pihak ketiga.

---

## 🚀 Cara Menjalankan

### 1. Jalankan Aplikasi Langsung
Cukup klik ganda **`MouseBack.app`** di folder ini, atau jalankan melalui Terminal:
```bash
open MouseBack.app
```

*(Opsional: Anda bisa memindahkan `MouseBack.app` ke folder `/Applications` Mac Anda jika ingin dipasang permanen).*

### 2. Berikan Izin Aksesibilitas (Hanya Sekali di Awal)
Karena macOS memerlukan izin keamanan untuk mendeteksi tombol mouse tambahan:
1. Saat aplikasi dibuka, macOS akan menampilkan dialog izin aksesibilitas.
2. Klik tombol **Open System Settings** (atau buka menu bar MouseBack > **Buka Pengaturan Aksesibilitas...**).
3. Masuk ke **Privacy & Security** > **Accessibility**.
4. Aktifkan sakelar toggle untuk **MouseBack**.
5. Ikon di Menu Bar akan otomatis berubah menjadi status **🟢 MouseBack: Aktif** tanpa perlu me-restart aplikasi!

---

## ⚙️ Opsi di Menu Bar

Klik ikon mouse di status bar atas layar untuk mengakses menu:
- **Status**: Menampilkan status saat ini (*Aktif*, *Nonaktif*, atau *Butuh Izin Aksesibilitas*).
- **Aktifkan MouseBack**: Menyalakan atau mematikan fungsi tombol samping kapan saja.
- **Tukar Tombol Samping (Swap Back / Forward)**: Centang jika Anda ingin tombol depan menjadi Back dan tombol belakang menjadi Forward.
- **Buka Otomatis saat Login**: Menjadikan aplikasi otomatis berjalan di background saat Mac menyala.
- **Buka Pengaturan Aksesibilitas...**: Pintasan cepat ke Pengaturan Sistem macOS.
- **Keluar**: Menutup aplikasi sepenuhnya.

---

## 🛠️ Kompilasi Ulang (Build)

Jika Anda ingin mengubah kode di folder `Sources/`, cukup jalankan:
```bash
./build.sh
```
Skrip ini akan mengompilasi ulang kode sumber Swift dan menghasilkan bundle `MouseBack.app` yang sudah ditandatangani (*ad-hoc codesigned*).
