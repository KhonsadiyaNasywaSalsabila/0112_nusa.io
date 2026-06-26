const express = require('express');
const router = express.Router();
const { 
  bookmarkLocation, getBookmarkedLocations, removeBookmarkedLocation, removeBookmarkedLocationByLocationId,
  saveJournal, getSavedJournals, unsaveJournal, unsaveJournalByJournalId
} = require('../controllers/bookmarkController');
const { authenticateToken } = require('../middlewares/authMiddleware');

router.use(authenticateToken);

// Lokasi (Rencana Jelajah)
router.post('/locations', bookmarkLocation);
router.get('/locations', getBookmarkedLocations);
router.delete('/locations/:id', removeBookmarkedLocation);
router.delete('/locations/by-location/:locationId', removeBookmarkedLocationByLocationId);

// Jurnal (Koleksi Inspirasi)
router.post('/journals', saveJournal);
router.get('/journals', getSavedJournals);
router.delete('/journals/:id', unsaveJournal);
router.delete('/journals/by-journal/:journalId', unsaveJournalByJournalId);

module.exports = router;