const express = require('express');
const router = express.Router();
const { addBookmark, getBookmarks, removeBookmark } = require('../controllers/bookmarkController');
const { authenticateToken } = require('../middlewares/authMiddleware');

// Wajib login buat akses bookmark
router.use(authenticateToken);

router.post('/', addBookmark);
router.get('/', getBookmarks);
router.delete('/:id', removeBookmark);

module.exports = router;