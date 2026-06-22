const prisma = require('../config/prisma');

// --- 1. Tambah ke Rencana Jelajah (Dengan Proteksi Anti-Race Condition) ---
const addBookmark = async (req, res) => {
  try {
    const userId = req.user.id;
    const { journalId } = req.body;

    if (!journalId) {
      return res.status(400).json({ success: false, message: "Journal ID wajib diisi." });
    }

    // 1. Tarik data jurnalnya dulu buat ngecek keberadaannya DAN ngambil locationId-nya
    const journalTarget = await prisma.journal.findUnique({
      where: { id: journalId }
    });

    if (!journalTarget) {
      return res.status(404).json({ success: false, message: "Jurnal yang mau disimpan tidak ditemukan." });
    }

    // 2. IMPLEMENTASI FASE 2 & 4: Cek stempel kehadiran untuk menentukan status awal
    // Jika user sudah pernah mendapatkan stempel di lokasi ini, otomatis langsung 'VISITED'
    const existingStamp = await prisma.userStamp.findFirst({
      where: { 
        userId: userId, 
        locationId: journalTarget.locationId 
      }
    });

    const bookmarkStatus = existingStamp ? 'VISITED' : 'PLANNED';

    // 3. Simpan ke database (Memanfaatkan database constraint UNIQUE)
    const newBookmark = await prisma.bookmark.create({
      data: { 
        userId: userId, 
        journalId: journalId,
        locationId: journalTarget.locationId,
        status: bookmarkStatus
      }
    });

    return res.status(201).json({ 
      success: true, 
      message: "Berhasil disimpan ke Rencana Jelajah!", 
      data: newBookmark 
    });

  } catch (error) {
    // =====================================================================
    // KUNCI UTAMA FASE 4: Tangkap Pelanggaran Unique Constraint (P2002)
    // akibat double-tap tombol simpan / race condition di sisi client.
    // =====================================================================
    if (error.code === 'P2002') {
      return res.status(400).json({ 
        success: false, 
        message: "Jejak ini sudah ada di Rencana Jelajahmu!" 
      });
    }

    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menyimpan jejak." });
  }
};

// --- 2. Lihat Semua Rencana Jelajah ---
const getBookmarks = async (req, res) => {
  try {
    const userId = req.user.id;

    const bookmarks = await prisma.bookmark.findMany({
      where: { userId: userId },
      include: {
        location: true,
        journal: {
          include: { 
            user: { select: { username: true } } 
          } 
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    return res.status(200).json({ success: true, data: bookmarks });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal mengambil daftar rencana jelajah." });
  }
};

// --- 3. Hapus dari Rencana Jelajah (Dengan Validasi Kepemilikan) ---
const removeBookmark = async (req, res) => {
  try {
    const { id } = req.params; // ID bookmark-nya
    const userId = req.user.id;

    // Tambahan Keamanan: Pastikan data ada dan hanya pemilik yang bisa menghapus
    const bookmark = await prisma.bookmark.findUnique({
      where: { id: id }
    });

    if (!bookmark) {
      return res.status(404).json({ success: false, message: "Rencana jelajah tidak ditemukan." });
    }

    if (bookmark.userId !== userId) {
      return res.status(403).json({ success: false, message: "Kamu tidak berhak menghapus rencana jelajah ini!" });
    }
    
    // Eksekusi hapus data
    await prisma.bookmark.delete({
      where: { id: id }
    });

    return res.status(200).json({ success: true, message: "Jejak dihapus dari rencana jelajah." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menghapus jejak." });
  }
};

module.exports = { addBookmark, getBookmarks, removeBookmark };