const { validationResult } = require('express-validator');

// Ini adalah Satpam Global kita
const runValidation = (req, res, next) => {
  const errors = validationResult(req);
  
  // Jika ada aturan yang dilanggar
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      // Kita ambil pesan error pertama saja agar rapi saat dibaca oleh Flutter
      message: errors.array()[0].msg 
    });
  }
  
  // Jika aman, persilakan masuk ke Controller
  next();
};

module.exports = { runValidation };