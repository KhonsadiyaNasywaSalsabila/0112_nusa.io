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

// --- API UPDATE PROFILE ---
const updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    const { username, bio } = req.body;

    if (username) {
      const existingUser = await prisma.user.findFirst({
        where: { username, id: { not: userId } }
      });
      if (existingUser) {
        return res.status(400).json({ success: false, message: "Username sudah digunakan!" });
      }
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        username: username !== undefined ? username : undefined,
        bio: bio !== undefined ? bio : undefined
      },
      select: { id: true, username: true, bio: true, profilePhotoUrl: true }
    });

    res.status(200).json({ success: true, message: "Profil berhasil diperbarui", data: updatedUser });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal memperbarui profil" });
  }
};

// --- API UPDATE PASSWORD ---
const updatePassword = async (req, res) => {
  try {
    const userId = req.user.id;
    const { oldPassword, newPassword } = req.body;

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ success: false, message: "Akun tidak ditemukan!" });
    }

    const isMatch = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Password lama salah!" });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash: hashedPassword }
    });

    res.status(200).json({ success: true, message: "Password berhasil diperbarui!" });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal memperbarui password" });
  }
};

// --- API DELETE ACCOUNT (SOFT DELETE) ---
const deleteAccount = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // Soft Delete: Anonymize user to keep journals and replies intact
    const randomSuffix = Math.random().toString(36).substring(2, 8);
    const anonymizedUsername = `[Pengguna Dihapus ${randomSuffix}]`;

    await prisma.user.update({
      where: { id: userId },
      data: {
        username: anonymizedUsername,
        email: `deleted_${userId}@nusa.io`, // Prevent email collision if they sign up again
        passwordHash: "*", // Invalid hash
        bio: "",
        profilePhotoUrl: null,
        accountStatus: "SUSPEND"
      }
    });

    res.status(200).json({ success: true, message: "Akun berhasil dihapus. Sampai jumpa kembali!" });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal menghapus akun" });
  }
};

// Ekspor fungsi baru
module.exports = { register, login, getProfile, updateAvatar, updateProfile, updatePassword, deleteAccount };