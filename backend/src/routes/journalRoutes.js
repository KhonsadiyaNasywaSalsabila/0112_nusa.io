const express = require('express');
const router = express.Router();

// Import ke-8 fungsi dari controller
const { 
  createJournal, 
  getJournals,
  updateJournal, 
  deleteJournal, 
  archiveJournal,
  getDrafts, 
  publishJournal, 
  syncJournals,
  reportJournal 
} = require('../controllers/journalController');

const { authenticateToken } = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware'); // Satpam foto (multer)

// Semua API Jurnal di bawah ini butuh token (wajib login)
router.use(authenticateToken); 

// ==========================================================
// RUTE STATIS (WAJIB di atas rute dinamis /:id)
// ==========================================================

// Endpoint: GET /api/v1/journals/drafts
router.get('/drafts', getDrafts);

// Endpoint: POST /api/v1/journals/sync
router.post('/sync', syncJournals);

// Endpoint: POST /api/v1/journals (Create)
router.post('/', upload.array('photos', 3), createJournal);

// Endpoint: GET /api/v1/journals?page=1&limit=5&search=kata (Timeline / Explore)
router.get('/', getJournals);


// ==========================================================
// RUTE DINAMIS (Pakai parameter /:id)
// ==========================================================

// Endpoint: PATCH /api/v1/journals/:id/publish (Publish Manual)
router.patch('/:id/publish', publishJournal);

// Endpoint: PATCH /api/v1/journals/:id (Update / Edit Konten & Foto)
router.patch('/:id', upload.array('photos', 3), updateJournal);

// Endpoint: POST /api/v1/journals/:id/report (Fitur Laporkan)
router.post('/:id/report', reportJournal);

// Endpoint: PATCH /api/v1/journals/:id/archive (Gembok Jurnal / Simpan Sendiri)
router.patch('/:id/archive', archiveJournal);

// Endpoint: DELETE /api/v1/journals/:id (Hapus Jurnal Permanen)
router.delete('/:id', deleteJournal);

module.exports = router;