<<<<<<< HEAD
# nusa.io - Jejak Digital Tanpa Batas

**nusa.io** adalah ekosistem aplikasi perpaduan antara **Mobile (Flutter)** untuk wisatawan dan **Dasbor Web (React.js)** untuk admin. Dibangun di atas fondasi **Node.js, Express, dan Prisma ORM**, aplikasi ini merevolusi cara wisatawan meninggalkan jejak jurnal digital berbasis lokasi nyata (*Geofencing*) serta membangun komunitas komunal di setiap titik wisata.

---

## 🌟 Daftar Fitur Lengkap (Features List)

### 📱 Aplikasi Mobile (Flutter) - Sisi Wisatawan
Aplikasi interaktif bagi para pelancong untuk meninggalkan dan membaca jejak (*Scrapbook* digital) langsung di tempatnya.

1. **Autentikasi & Personalisasi Profil**
   - Registrasi dan Login aman berbasis JWT.
   - **Mode Tamu (Guest Mode):** Jelajahi peta dan baca-baca jurnal tanpa perlu membuat akun.
   - Dasbor Profil: Kustomisasi Bio, Foto, melihat total jejak, dan galeri Stempel Paspor.

2. **Map Explore (Peta Eksplorasi)**
   - Integrasi langsung dengan **Google Maps SDK**.
   - **Dynamic Heatmap / Glow Effect:** Semakin banyak jurnal di suatu tempat, semakin besar dan pekat radius cahaya oranye di peta.
   - **Filter Tema Interaktif:** Saring kemunculan titik berdasarkan *mood* atau tema jurnal (Alam, Kuliner, *Vintage*, Sosial, Personal, *Mindful*).

3. **Penulisan Jurnal Berbasis Geofence & Offline-First**
   - **Validasi Geofence Ketat:** Wisatawan HANYA bisa memublikasikan jurnal (mendapatkan stempel) jika koordinat GPS *real-time* berada di dalam radius lokasi aslinya (Haversine Formula).
   - **Proteksi Anti-Fake GPS:** Menolak eksekusi jika terdeteksi penggunaan lokasi palsu.
   - **Arsitektur Offline-First:** Saat tidak ada sinyal internet (seperti di gunung) atau di luar radius, jurnal akan ditampung di **Database SQLite Lokal** (Draf) di HP, siap disinkronkan (*Batch Sync*) saat sudah terhubung.
   - Lampiran Media: Unggah foto autentik bersama teks.

4. **PlaceHub (Linimasa Komunal)**
   - Forum lokal mini untuk setiap lokasi wisata.
   - **Nested Replies:** Balas-balasan (*Thread*) pada jurnal wisatawan lain.
   - Fitur *Report* untuk melaporkan konten melanggar kepada admin.
   - Penarikan Jurnal (*Soft/Hard Delete*) & Arsip Privat.

5. **Gamifikasi & *Bookmark***
   - **Stempel Lokasi Eksklusif:** Secara otomatis terkumpul setiap kali berhasil menulis jejak (cek in) di titik wisata.
   - **Simpan Jejak (Daftar Impian):** Menyimpan jurnal inspiratif dari orang lain, dengan status progres (*Planned* vs *Visited*).

---

### 💻 Dasbor Web (React.js) - Sisi Admin
Pusat komando responsif bergaya moderen/gelap (*Dark/Glassmorphism*) untuk mengatur ekosistem nusa.io.

1. **Keamanan Berlapis & Otorisasi**
   - **Anti-XSS:** Autentikasi ketat menggunakan sandi `HTTPOnly Cookie` (Token sama sekali tidak terekspos di browser).
   - **Role-Based Access Control (RBAC):** Hierarki hak akses antara `SUPER_ADMIN` (Akses penuh) dan `MODERATOR` (Terbatas pada moderasi).

2. **Manajemen Master Data Lokasi** *(Khusus Super Admin)*
   - Membuat entitas titik wisata baru (dengan koordinat *Latitude/Longitude* dan Radius toleransi Geofence dalam meter).
   - Unggah foto sampul lokasi.
   - **Toggle Arsip:** Tutup lokasi wisata dari peta mobile secara *real-time* dengan satu klik.

3. **Moderasi Konten & Komunitas** *(Moderator & Super Admin)*
   - Meja persidangan untuk jurnal-jurnal yang dilaporkan oleh komunitas (*Report Flagging*).
   - **Blokir Real-time:** Sekali palu diketok (Blokir), jurnal seketika lenyap dari pandangan publik (termasuk pengurangan radius *glow* di peta).
   
4. **Kelola Akun Pengguna**
   - Melacak metrik partisipasi setiap pengguna.
   - **Penegakan Disiplin:** Mengunci paksa akun yang toxic dengan status `SUSPEND` (Sementara) atau `BANNED` (Permanen).

---

## 🛠️ Stack Teknologi (Tech Stack)

**Backend API:**
- Node.js & Express.js
- Prisma ORM
- MySQL Database
- JWT & HTTPOnly Cookies
- Multer (File Upload)

**Mobile Frontend:**
- Flutter & Dart
- BLoC (State Management)
- SQLite (sqflite) untuk Draf Offline
- Google Maps Flutter

**Admin Frontend:**
- React.js (Vite)
- Zustand (State Management)
- TailwindCSS (Styling)
- Axios (Interceptor & Credentials)

---

## 📅 Log Progres Mingguan (6 Minggu)

**Minggu 1: Fondasi Sistem & Desain Database**
- Perancangan UI/UX (*Wireframing*).
- Inisialisasi kerangka proyek Node.js (Backend), Flutter (Mobile), dan React Vite (Admin).
- Rancang bangun relasi database menggunakan Prisma ORM.
- Implementasi API Autentikasi (Register/Login) dengan keamanan JWT.

**Minggu 2: Peta & Manajemen Titik Master**
- Integrasi Google Maps SDK di aplikasi Flutter.
- Implementasi antarmuka *Map Explore* dengan penanda lokasi kustom.
- Pembuatan API CRUD Master Lokasi di sisi *Backend*.
- Pembangunan antarmuka Dasbor Admin (`Locations.jsx`) untuk input batas radius *geofence*.

**Minggu 3: Logika Geofencing & Mode Luring (Offline)**
- Implementasi Formula Haversine untuk kalkulasi jarak radius GPS nyata vs pusat lokasi.
- Konfigurasi database SQLite (`sqflite`) di Flutter.
- Pembuatan fitur penulisan Draf Jurnal dan integrasi penampungan *offline-first* tanpa internet.

**Minggu 4: Arsitektur BLoC & PlaceHub**
- Injeksi *State Management* (BLoC) untuk Autentikasi, Jurnal, dan Lokasi.
- Pembangunan antarmuka forum "PlaceHub" (Linimasa komunal setiap titik wisata).
- Implementasi sistem gamifikasi: pemberian Stempel Paspor otomatis pasca *check-in* tervalidasi.

**Minggu 5: Sinkronisasi Awan & Kontrol Akses Admin**
- Implementasi layanan `Batch Sync` untuk menyinkronkan tumpukan draf SQLite ke peladen.
- Pembuatan fitur *Bookmark* (Simpan Jejak Impian).
- Integrasi *Role-Based Access Control* (RBAC) memisahkan wewenang *Super Admin* dan *Moderator*.

**Minggu 6: Moderasi, Pengujian, dan Finalisasi**
- Pembuatan portal sidang moderasi (`Journals.jsx`) bagi admin untuk memblokir/menyembunyikan konten pelanggar seketika dari peta.
- Pembersihan keamanan (Penerapan *HTTPOnly Cookies* dan proteksi CORS dinamis).
- *Bug-fixing* komprehensif, penghalusan animasi (*micro-interactions*), dan validasi akhir NFR.
- Penulisan dokumentasi teknis, penyempurnaan `README.md`, dan perapihan riwayat repositori Git.
=======
# Problem Statement
Dalam era digitalisasi saat ini, dokumentasi perjalanan (*travel journaling*) telah bergeser dari refleksi
personal yang mendalam menjadi sekadar konsumsi visual instan di media sosial arus utama. Fenomena ini
memicu beberapa permasalahan mendasar yang ingin diselesaikan oleh Nusa.io:
1. Komodifikasi Kenangan Wisata & Distraksi Feed: Platform sosial umum (seperti Instagram atau
TikTok) dirancang dengan algoritma yang mengejar interaksi (*engagement*) tanpa akhir. Hal ini membuat
jurnal perjalanan personal pengguna mudah tenggelam dalam tumpukan konten yang tidak relevan,
menghilangkan esensi intim dan reflektif dari sebuah catatan perjalanan.
2. Kehilangan Konteks Spasial (Ruang Geografis): Cerita dan foto perjalanan sering kali terisolasi secara
digital tanpa ikatan yang kuat dengan lokasi fisik tempat kenangan tersebut dibuat. Pengguna kesulitan
mengeksplorasi suatu daerah berdasarkan kumpulan cerita emosional yang benar-benar terikat pada titik
koordinat geografis nyata.
3. Kerentanan Integritas Data Wisata (Manipulasi Spasial): Banyak aplikasi berbasis lokasi yang
kebobolan oleh manipulasi koordinat palsu (*Fake GPS*) dan konten sampah (*spam*). Hal ini merusak
keandalan data destinasi wisata bagi komunitas pelancong yang membutuhkan rekomendasi atau catatan
autentik dari orang yang benar-benar berada di lokasi tersebut.
4. Antarmuka yang Padat dan Melelahkan (*Cluttered UI*): Aplikasi modern sering kali membebani
kognitif pengguna dengan terlalu banyak navigasi, iklan, dan pop-up. Pelancong kehilangan ruang tenang
(*Zen*) yang mereka butuhkan untuk menuliskan kenangan atau meresapi cerita perjalanan orang lain
secara fokus.


# List Features
## Aplikasi Mobile (Flutter) - Sisi Wisatawan
1. Autentikasi dan Personalisasi Profil
2. Mode Tamu
3. Map Explorer
4. Filter Tema Interaktif
5. Penulisan Jurnal Berbasis Geofence dan Offline-First
6. PlaceHub
7. Gamifikasi dan Bookmark

## Dasbor Web (React.js) - Sisi Admin
1. Keamanan Berlapis & Otorisasi
2. Manajemen Master Data Lokasi
3. Moderasi Konten & Komunitas
4. Kelola Akun Pengguna

# Log Progress Mingguan
## Minggu 1: Fondasi Sistem & Desain Database
1. Inisialisasi kerangka proyek Node.js (Backend), Flutter (Mobile), dan React Vite (Admin).
2. Rancang bangun relasi database menggunakan Prisma ORM.
3. Implementasi API Autentikasi (Register/Login) dengan keamanan JWT.
   
## Minggu 2: Peta & Manajemen Titik Master
1. Integrasi Google Maps SDK di aplikasi Flutter.
2. Implementasi antarmuka *Map Explore* dengan penanda lokasi kustom.
3. Pembuatan API CRUD Master Lokasi di sisi *Backend*.
4. Pembangunan antarmuka Dasbor Admin (`Locations.jsx`) untuk input batas radius *geofence*.

## Minggu 3: Logika Geofencing & Mode Luring (Offline)
1. Implementasi Formula Haversine untuk kalkulasi jarak radius GPS nyata vs pusat lokasi.
2. Konfigurasi database SQLite (`sqflite`) di Flutter.
3. Pembuatan fitur penulisan Draf Jurnal dan integrasi penampungan *offline-first* tanpa internet.

## Minggu 4: Arsitektur BLoC & PlaceHub
1. Injeksi *State Management* (BLoC) untuk Autentikasi, Jurnal, dan Lokasi.
2. Pembangunan antarmuka forum "PlaceHub" (Linimasa komunal setiap titik wisata).
3. Implementasi sistem gamifikasi: pemberian Stempel Paspor otomatis pasca *check-in* tervalidasi.

## Minggu 5: Sinkronisasi Awan & Kontrol Akses Admin
1. Implementasi layanan `Batch Sync` untuk menyinkronkan tumpukan draf SQLite ke server.
2. Pembuatan fitur *Bookmark* (Simpan Jejak Impian).
3. Integrasi *Role-Based Access Control* (RBAC) memisahkan wewenang *Super Admin* dan *Moderator*.

## Minggu 6: Moderasi, Pengujian, dan Finalisasi
1. Pembuatan portal sidang moderasi (`Journals.jsx`) bagi admin untuk memblokir/menyembunyikan konten pelanggar seketika dari peta.
2. Pembersihan keamanan (Penerapan *HTTPOnly Cookies* dan proteksi CORS dinamis).
3. *Bug-fixing* komprehensif, penghalusan animasi (*micro-interactions*), dan validasi akhir NFR.
4. Penulisan dokumentasi teknis, penyempurnaan `README.md`, dan perapihan riwayat repositori Git.
>>>>>>> a91f135e2f02b1b1d458cc8a7dc8161485a5be5d
