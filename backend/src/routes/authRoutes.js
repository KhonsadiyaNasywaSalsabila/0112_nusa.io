const express = require('express');
const router = express.Router();

// 1. Import Controller Utama
const { register, login, getProfile, updateAvatar } = require('../controllers/authController');

// 2. Import Aturan Validasi dan Satpam Penindak (Fase Baru)
const { registerValidation, loginValidation } = require('../middlewares/validators/authValidator');
const { runValidation } = require('../middlewares/validateMiddleware');

// 3. Import Middleware Tambahan (Token & Upload)
const { authenticateToken } = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');

// ==========================================================
// ENDPOINT PUBLIK (Tidak butuh token JWT)
// ==========================================================
// Urutan: Rute -> Buku Aturan -> Satpam Pengecek -> Eksekusi Controller
router.post('/register', registerValidation, runValidation, register);
router.post('/login', loginValidation, runValidation, login);

// ==========================================================
// ENDPOINT PRIVATE (Butuh token JWT)
// ==========================================================
router.get('/me', authenticateToken, getProfile);

// Endpoint Update Avatar
// Urutan: Cek Token -> Tangkap File 'avatar' -> Eksekusi Controller
router.patch('/me/avatar', authenticateToken, upload.single('avatar'), updateAvatar);

module.exports = router;