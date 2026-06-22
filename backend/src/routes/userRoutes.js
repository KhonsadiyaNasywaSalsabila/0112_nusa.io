const express = require('express');
const router = express.Router();
const { getUserStamps, getUserArchives, getUserMemories } = require('../controllers/userController');
const { authenticateToken } = require('../middlewares/authMiddleware');

router.use(authenticateToken); // Wajib login

router.get('/me/stamps', getUserStamps);
router.get('/me/archives', getUserArchives);
router.get('/me/memories', getUserMemories);

module.exports = router;
