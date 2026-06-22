const express = require('express');
const router = express.Router();
const upload = require('../middlewares/uploadMiddleware');
const { authenticateToken } = require('../middlewares/authMiddleware');

router.use(authenticateToken);

// Endpoint: POST /api/v1/media/upload
router.post('/upload', upload.array('photos', 3), (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ success: false, message: "Tidak ada foto yang diunggah." });
    }

    const mediaUrls = req.files.map(file => `/uploads/${file.filename}`);

    res.status(201).json({
      success: true,
      message: "Foto berhasil diunggah.",
      data: mediaUrls
    });
  } catch (error) {
    console.error("Error upload media:", error);
    res.status(500).json({ success: false, message: "Gagal mengunggah foto." });
  }
});

module.exports = router;
