const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

// --- API REGISTER ---
const register = async (req, res) => {
  try {
    const { username, email, password } = req.body;

    const existingUser = await prisma.user.findFirst({
      where: { OR: [{ email }, { username }] }
    });

    if (existingUser) {
      return res.status(400).json({ success: false, message: "Email atau Username sudah terdaftar!" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    const newUser = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash: hashedPassword,
      }
    });

    res.status(201).json({
      success: true,
      message: "Registrasi berhasil! Silakan login.",
      data: { id: newUser.id, username: newUser.username }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Terjadi kesalahan di server." });
  }
};

// --- API LOGIN ---
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return res.status(404).json({ success: false, message: "Akun tidak ditemukan!" });
    }

    if (user.accountStatus !== 'ACTIVE') {
      return res.status(403).json({ success: false, message: `Akses ditolak! Status akun: ${user.accountStatus}` });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Password salah!" });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, status: user.accountStatus },
      process.env.JWT_SECRET,
      { expiresIn: '7d' } 
    );

    res.status(200).json({
      success: true,
      message: "Login berhasil!",
      token: token,
      data: { id: user.id, username: user.username }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Terjadi kesalahan di server." });
  }
};

// --- API GET PROFILE ---
const getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { 
        id: true, 
        username: true, 
        email: true, 
        bio: true, 
        accountStatus: true,
        profilePhotoUrl: true, // <-- TAMBAHAN: Sekarang aplikasi bisa menampilkan avatar
        createdAt: true 
      } 
    });

    if (!user) {
      return res.status(404).json({ success: false, message: "User tidak ditemukan" });
    }

    res.status(200).json({ success: true, data: user });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Terjadi kesalahan di server." });
  }
};

// --- API UPDATE AVATAR (FASE 6) ---
const updateAvatar = async (req, res) => {
  try {
    const userId = req.user.id; // Didapat dari authMiddleware

    // Cek apakah ada file yang berhasil diunggah oleh uploadMiddleware
    if (!req.file) {
      return res.status(400).json({ success: false, message: "Tidak ada foto yang diunggah!" });
    }

    // Buat URL lokal untuk foto
    const photoUrl = `/uploads/${req.file.filename}`;

    // Update data user di database MySQL
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { profilePhotoUrl: photoUrl },
      select: { username: true, profilePhotoUrl: true } // Kembalikan data yang perlu saja
    });

    res.status(200).json({ 
      success: true, 
      message: "Foto profil berhasil diperbarui!", 
      data: updatedUser 
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal memperbarui foto profil." });
  }
};

// Ekspor fungsi baru
module.exports = { register, login, getProfile, updateAvatar };