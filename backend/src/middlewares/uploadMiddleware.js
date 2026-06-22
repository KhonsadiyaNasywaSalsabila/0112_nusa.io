const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Bikin folder 'uploads' otomatis kalau belum ada
const uploadDir = 'uploads/';
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

// Konfigurasi penyimpanan lokal
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir); // Simpan ke folder uploads/
  },
  filename: (req, file, cb) => {
    // Ubah nama file biar unik (contoh: 168493829.jpg)
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

// Filter khusus gambar & limit ukuran maksimal 5MB
const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, 
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Hanya diperbolehkan mengunggah file gambar!'), false);
    }
  }
});

module.exports = upload;