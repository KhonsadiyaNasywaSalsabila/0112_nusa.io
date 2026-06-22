// File: backend/server.js
const express = require('express');
const cors = require('cors');
const cookieParser = require('cookie-parser');
require('dotenv').config();

// Inisialisasi Express
const app = express();
const PORT = process.env.PORT || 3000;

// Tentukan origin CORS berdasarkan Environment (Produksi vs Dev)
const allowedOrigins = process.env.ADMIN_CORS_ORIGIN 
  ? process.env.ADMIN_CORS_ORIGIN.split(',') 
  : ['http://localhost:5173', 'http://localhost:5174'];

// Middleware (Penjaga Gerbang)
app.use(cors({
  origin: allowedOrigins,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  credentials: true
})); // Mengizinkan request dari luar (Flutter dan Web Admin)
app.use(express.json()); // Menerjemahkan body request menjadi format JSON
app.use(cookieParser()); // Parsing cookie HTTPOnly
// Izinkan akses ke folder gambar
app.use('/uploads', express.static('uploads'));
app.use(express.urlencoded({ extended: true }));

// --- IMPORT ROUTES ---
const authRoutes = require('./src/routes/authRoutes');
const journalRoutes = require('./src/routes/journalRoutes');
const locationRoutes = require('./src/routes/locationRoutes');
const bookmarkRoutes = require('./src/routes/bookmarkRoutes');
const mapRoutes = require('./src/routes/mapRoutes');
const mediaRoutes = require('./src/routes/mediaRoutes');
const userRoutes = require('./src/routes/userRoutes');
const adminRoutes = require('./src/routes/adminRoutes');

// --- DAFTARKAN ROUTES ---
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/journals', journalRoutes);
app.use('/api/v1/locations', locationRoutes);
app.use('/api/v1/bookmarks', bookmarkRoutes);
app.use('/api/v1/map', mapRoutes);
app.use('/api/v1/media', mediaRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/admin', adminRoutes);

// Rute Dasar (Health Check)
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: "Selamat datang di API nusa.io! Peladen berjalan dengan baik.",
    version: "1.0.0"
  });
});

// Menyalakan Peladen
app.listen(PORT, () => {
  console.log(`🚀 Peladen nusa.io berhasil menyala di http://localhost:${PORT}`);
});