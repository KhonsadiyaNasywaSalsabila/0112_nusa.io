const { body } = require('express-validator');

const registerValidation = [
  body('username')
    .notEmpty().withMessage('Username tidak boleh kosong.')
    .isLength({ min: 3 }).withMessage('Username minimal 3 karakter.'),
  
  body('email')
    .notEmpty().withMessage('Email tidak boleh kosong.')
    .isEmail().withMessage('Format email tidak valid.'),
  
  body('password')
    .notEmpty().withMessage('Password tidak boleh kosong.')
    .isLength({ min: 6 }).withMessage('Password minimal 6 karakter.')
];

const loginValidation = [
  body('email')
    .notEmpty().withMessage('Email wajib diisi.')
    .isEmail().withMessage('Format email tidak valid.'),
    
  body('password')
    .notEmpty().withMessage('Password wajib diisi.')
];

module.exports = { registerValidation, loginValidation };