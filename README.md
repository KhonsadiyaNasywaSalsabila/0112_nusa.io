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
