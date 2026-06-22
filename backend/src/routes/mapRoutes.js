const express = require('express');
const router = express.Router();

const { getMapData } = require('../controllers/mapController');
const { optionalAuth } = require('../middlewares/authMiddleware');

// ==========================================================
// RUTE FASE 3: EKSPLORASI PETA (DYNAMIC THEMES)
// ==========================================================
// Alamat lengkapnya: GET http://localhost:3000/api/v1/map
router.get('/', optionalAuth, getMapData);

module.exports = router;
