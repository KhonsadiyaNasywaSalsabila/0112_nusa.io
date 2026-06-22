const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');

// =====================================================================
// FASE 1: AUTH & MANAGEMENT ADMIN
// =====================================================================

// --- 1. Login Admin ---
const adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    const admin = await prisma.admin.findUnique({ where: { email } });
    if (!admin) {
      return res.status(401).json({ success: false, message: "Kredensial tidak valid." });
    }

    const isMatch = await bcrypt.compare(password, admin.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Kredensial tidak valid." });
    }

    const token = jwt.sign(
      { id: admin.id, role: admin.role, username: admin.username },
      process.env.JWT_SECRET || 'secret_key',
      { expiresIn: '1d' }
    );

    res.cookie('token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 24 * 60 * 60 * 1000 // 1 day
    });

    res.status(200).json({
      success: true,
      message: "Login admin berhasil.",
      data: {
        admin: { id: admin.id, username: admin.username, email: admin.email, role: admin.role }
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal login admin." });
  }
};

const adminLogout = (req, res) => {
  res.clearCookie('token', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict'
  });
  res.status(200).json({ success: true, message: "Logout admin berhasil." });
};

// --- 2. Create Admin (Hanya SUPER_ADMIN) ---
const createAdmin = async (req, res) => {
  try {
    const { username, email, password, role } = req.body;

    if (!['SUPER_ADMIN', 'MODERATOR'].includes(role)) {
      return res.status(400).json({ success: false, message: "Role tidak valid." });
    }

    const existing = await prisma.admin.findFirst({
      where: { OR: [{ email }, { username }] }
    });

    if (existing) {
      return res.status(400).json({ success: false, message: "Email atau username sudah terdaftar." });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const newAdmin = await prisma.admin.create({
      data: { username, email, passwordHash, role }
    });

    res.status(201).json({
      success: true,
      message: `Akun ${role} berhasil dibuat.`,
      data: { id: newAdmin.id, username: newAdmin.username, role: newAdmin.role }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal membuat admin baru." });
  }
};

// =====================================================================
// FASE 2: MODERASI KONTEN & AKUN
// =====================================================================

// --- 3. Get Reported Journals ---
const getReportedJournals = async (req, res) => {
  try {
    const journals = await prisma.journal.findMany({
      where: { 
        OR: [
          { reportCount: { gt: 0 } },
          { status: 'BLOCKED' }
        ]
      },
      orderBy: { reportCount: 'desc' },
      include: {
        user: { select: { username: true, email: true } },
        location: { select: { name: true } },
        media: true
      }
    });
    res.status(200).json({ success: true, data: journals });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengambil daftar laporan." });
  }
};

// --- 4. Toggle Block Journal ---
const toggleBlockJournal = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'BLOCKED' or 'PUBLISHED'

    const journal = await prisma.journal.findUnique({ where: { id } });
    if (!journal) {
      return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    }

    if (journal.status === status) {
      return res.status(200).json({ success: true, message: "Status sudah sesuai." });
    }

    const updatedJournal = await prisma.journal.update({
      where: { id },
      data: { status }
    });

    if (journal.status === 'PUBLISHED' && status === 'BLOCKED') {
      await prisma.location.update({
        where: { id: journal.locationId },
        data: { journalCount: { decrement: 1 } }
      });
    } else if (journal.status === 'BLOCKED' && status === 'PUBLISHED') {
      await prisma.location.update({
        where: { id: journal.locationId },
        data: { journalCount: { increment: 1 } }
      });
    }

    res.status(200).json({
      success: true,
      message: `Jurnal berhasil diubah menjadi ${status}.`,
      data: updatedJournal
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal merubah status jurnal." });
  }
};

// --- 5. Get Users ---
const getUsers = async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        username: true,
        email: true,
        accountStatus: true,
        createdAt: true,
        _count: {
          select: { journals: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengambil daftar pengguna." });
  }
};

// --- 6. Update User Status (Suspend/Ban) ---
const updateUserStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { accountStatus } = req.body;

    if (!['ACTIVE', 'SUSPEND', 'BANNED'].includes(accountStatus)) {
      return res.status(400).json({ success: false, message: "Status akun tidak valid." });
    }

    const updatedUser = await prisma.user.update({
      where: { id },
      data: { accountStatus }
    });

    res.status(200).json({
      success: true,
      message: `Status akun pengguna diubah menjadi ${accountStatus}.`,
      data: { id: updatedUser.id, username: updatedUser.username, accountStatus: updatedUser.accountStatus }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengubah status akun pengguna." });
  }
};

// =====================================================================
// FASE 3: MANAJEMEN MASTER LOKASI (CRUD)
// =====================================================================

// --- 6. Get All Locations (Admin View) ---
const getLocations = async (req, res) => {
  try {
    const locations = await prisma.location.findMany({
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: locations });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengambil daftar lokasi." });
  }
};

// --- 7. Create Location ---
const createLocation = async (req, res) => {
  try {
    const { latitude, longitude, name, geofenceRadius, description } = req.body;
    let coverPhotoUrl = null;

    if (req.file) {
      coverPhotoUrl = `/uploads/${req.file.filename}`;
    }

    const newLoc = await prisma.location.create({
      data: {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        name,
        geofenceRadius: parseInt(geofenceRadius, 10),
        description,
        ...(coverPhotoUrl && { coverPhotoUrl })
      }
    });

    res.status(201).json({ success: true, message: "Lokasi berhasil ditambahkan.", data: newLoc });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal menambahkan lokasi." });
  }
};

const updateLocation = async (req, res) => {
  try {
    const { id } = req.params;
    const { latitude, longitude, name, geofenceRadius, description, isActive } = req.body;
    let coverPhotoUrl = null;

    if (req.file) {
      coverPhotoUrl = `/uploads/${req.file.filename}`;
    }

    const updatedLoc = await prisma.location.update({
      where: { id },
      data: {
        ...(latitude && { latitude: parseFloat(latitude) }),
        ...(longitude && { longitude: parseFloat(longitude) }),
        ...(name && { name }),
        ...(geofenceRadius && { geofenceRadius: parseInt(geofenceRadius, 10) }),
        ...(description && { description }),
        ...(isActive !== undefined && { isActive: isActive === 'true' || isActive === true }),
        ...(coverPhotoUrl && { coverPhotoUrl })
      }
    });

    res.status(200).json({ success: true, message: "Lokasi berhasil diperbarui.", data: updatedLoc });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal memperbarui lokasi." });
  }
};

const deleteLocation = async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.location.update({ 
      where: { id },
      data: { isActive: false }
    });
    res.status(200).json({ success: true, message: "Lokasi berhasil diarsipkan (soft delete)." });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal menghapus lokasi." });
  }
};

module.exports = {
  adminLogin,
  adminLogout,
  createAdmin,
  getReportedJournals,
  toggleBlockJournal,
  getUsers,
  updateUserStatus,
  getLocations,
  createLocation,
  updateLocation,
  deleteLocation
};
