const express = require('express');
const router = express.Router();

// Import Controller aslimu yang sudah di-upgrade
const { getLocations, getLocationJournals } = require('../controllers/locationController');

// Import Satpam Santai
const { optionalAuth } = require('../middlewares/authMiddleware');

// ==========================================================
// RUTE FASE 3: EKSPLORASI PETA 
// ==========================================================
// Alamat lengkapnya: GET http://localhost:3000/api/v1/locations
router.get('/', optionalAuth, getLocations);

// RUTE FASE 7: PUSAT ARSIP LOKASI
// Alamat lengkapnya: GET http://localhost:3000/api/v1/locations/:id/journals
router.get('/:id/journals', optionalAuth, getLocationJournals);

module.exports = router;