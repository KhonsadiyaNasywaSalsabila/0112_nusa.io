const express = require('express');
const router = express.Router();
const upload = require('../middlewares/uploadMiddleware');

const {
  adminLogin,
  adminLogout,
  createAdmin,
  getReportedJournals,
  toggleBlockJournal,
  getUsers,
  updateUserStatus,
  getLocations,
  createLocation,
  updateLocation,
  deleteLocation
} = require('../controllers/adminController');

const { authenticateAdmin, requireRole } = require('../middlewares/authMiddleware');

// 1. PUBLIC ROUTE
router.post('/login', adminLogin);
router.post('/logout', adminLogout);

// ==========================================================
// SEMUA RUTE DI BAWAH INI WAJIB LOGIN SEBAGAI ADMIN
// ==========================================================
router.use(authenticateAdmin);

// 2. KELOLA ADMIN (Hanya SUPER_ADMIN)
router.post('/register-staff', requireRole(['SUPER_ADMIN']), createAdmin);

// 3. KELOLA MASTER LOKASI (Hanya SUPER_ADMIN)
// Frontend Dashboard bisa pakai endpoint GET /api/v1/map (public) untuk melihat daftar, tapi CRUD harus di sini
router.get('/locations', requireRole(['SUPER_ADMIN']), getLocations);
router.post('/locations', requireRole(['SUPER_ADMIN']), upload.single('coverPhoto'), createLocation);
router.patch('/locations/:id', requireRole(['SUPER_ADMIN']), upload.single('coverPhoto'), updateLocation);
router.delete('/locations/:id', requireRole(['SUPER_ADMIN']), deleteLocation);

// 4. MODERASI KONTEN (SUPER_ADMIN & MODERATOR)
router.get('/journals/reported', requireRole(['SUPER_ADMIN', 'MODERATOR']), getReportedJournals);
router.patch('/journals/:id/status', requireRole(['SUPER_ADMIN', 'MODERATOR']), toggleBlockJournal);

// 5. MODERASI AKUN (SUPER_ADMIN & MODERATOR)
router.get('/users', requireRole(['SUPER_ADMIN', 'MODERATOR']), getUsers);
router.patch('/users/:id/status', requireRole(['SUPER_ADMIN', 'MODERATOR']), updateUserStatus);

module.exports = router;
