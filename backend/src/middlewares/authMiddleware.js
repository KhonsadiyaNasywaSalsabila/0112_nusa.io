const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

// ==========================================================
// 1. SATPAM KETAT (Wajib Login)
// ==========================================================
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ 
      success: false, 
      message: "Akses ditolak! Token tidak ditemukan." 
    });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'secret_key', async (err, decoded) => {
    if (err) {
      return res.status(403).json({ 
        success: false, 
        message: "Token tidak valid atau sudah expired! Silakan login ulang." 
      });
    }

    try {
      const user = await prisma.user.findUnique({ where: { id: decoded.id } });
      if (!user) {
        return res.status(404).json({ success: false, message: "Pengguna tidak ditemukan." });
      }

      if (user.accountStatus === 'SUSPEND' || user.accountStatus === 'BANNED') {
        return res.status(403).json({ 
          success: false, 
          message: `Akun Anda dibekukan (${user.accountStatus}). Harap hubungi administrator.` 
        });
      }

      req.user = user;
      next();
    } catch (error) {
      console.error(error);
      res.status(500).json({ success: false, message: "Terjadi kesalahan internal server." });
    }
  });
};

// ==========================================================
// 2. SATPAM SANTAI (Tamu Lolos, User Lolos) -> Untuk Peta
// ==========================================================
const optionalAuth = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  // Jika tidak ada token, jangan ditolak. Set user sebagai Tamu (null) lalu persilakan lewat
  if (!token) {
    req.user = null;
    return next();
  }

  // Jika ada token, coba verifikasi siapa user-nya
  jwt.verify(token, process.env.JWT_SECRET || 'secret_key', async (err, decoded) => {
    if (err) {
      // Jika token kedaluwarsa atau manipulasi, anggap saja sebagai Tamu
      req.user = null;
      return next();
    } 
    
    try {
      // PENGECEKAN REAL-TIME KE DATABASE (Menjamin klaim SUSPEND/BANNED instan)
      const user = await prisma.user.findUnique({ where: { id: decoded.id } });
      
      // Jika user dihapus, dibekukan, atau diblokir permanen, lucuti hak aksesnya (paksa jadi Tamu)
      if (!user || user.accountStatus === 'SUSPEND' || user.accountStatus === 'BANNED') {
        req.user = null;
      } else {
        req.user = user;
      }
    } catch (error) {
      console.error("Gagal verifikasi optionalAuth:", error);
      req.user = null;
    }
    next();
  });
};

// ==========================================================
// 3. SATPAM ADMIN (Wajib Login Dasbor)
// ==========================================================
const authenticateAdmin = (req, res, next) => {
  // Ambil token dari cookie, fallback ke header Authorization jika diperlukan (misal postman)
  let token = req.cookies?.token;
  if (!token) {
    const authHeader = req.headers['authorization'];
    token = authHeader && authHeader.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ success: false, message: "Akses ditolak! Token admin tidak ditemukan." });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'secret_key', (err, admin) => {
    if (err) {
      return res.status(403).json({ success: false, message: "Sesi admin kedaluwarsa atau tidak valid." });
    }
    // Pastikan ini benar-benar token admin (mempunyai role)
    if (!admin.role) {
      return res.status(403).json({ success: false, message: "Akses ditolak. Token ini bukan milik Admin." });
    }
    req.admin = admin;
    next();
  });
};

// ==========================================================
// 4. PEMBATASAN HAK AKSES (RBAC)
// ==========================================================
const requireRole = (roles) => {
  return (req, res, next) => {
    if (!req.admin || !roles.includes(req.admin.role)) {
      return res.status(403).json({ 
        success: false, 
        message: `Hak akses ditolak. Hanya ${roles.join(' atau ')} yang diizinkan.` 
      });
    }
    next();
  };
};

module.exports = { authenticateToken, optionalAuth, authenticateAdmin, requireRole };