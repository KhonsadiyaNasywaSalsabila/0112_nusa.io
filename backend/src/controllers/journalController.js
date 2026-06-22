const prisma = require('../config/prisma');

// Import Service
const { checkGeofence, applyPublishSideEffects } = require('../services/geofenceService');
const { processBatchSync } = require('../services/syncService');

// =====================================================================
// FASE 2 & GAP CRUDS: FUNGSI DASAR (CREATE, READ, SEARCH, UPDATE, DELETE)
// =====================================================================

// --- 1. CREATE: Murni Hanya Menampung Draft ---
const createJournal = async (req, res) => {
  try {
    const userId = req.user.id; 
    
    const { locationId, content, themeTag, rootJournalId } = req.body;
    const latitudeCaptured = parseFloat(req.body.latitudeCaptured);
    const longitudeCaptured = parseFloat(req.body.longitudeCaptured);
    const isMocked = req.body.isMocked === 'true'; 

    if (isMocked) {
      return res.status(403).json({ success: false, message: "Fake GPS terdeteksi!" });
    }

    if (!content || content.trim() === '') {
      return res.status(400).json({ success: false, message: "Konten jurnal tidak boleh kosong." });
    }

    if (isNaN(latitudeCaptured) || isNaN(longitudeCaptured)) {
      return res.status(400).json({ success: false, message: "Koordinat tidak valid (NaN)." });
    }

    const location = await prisma.location.findUnique({ where: { id: locationId } });
    if (!location) return res.status(404).json({ success: false, message: "Lokasi tidak ditemukan." });

    if (location.isActive === false) {
      return res.status(403).json({ success: false, message: "Titik lokasi ini sudah ditutup/diarsipkan. Kamu tidak bisa menulis jurnal baru di sini." });
    }

    const newJournal = await prisma.journal.create({
      data: {
        userId, 
        locationId, 
        content, 
        themeTag, 
        latitudeCaptured, 
        longitudeCaptured, 
        ...(rootJournalId && { rootJournalId }) 
      }
    });

    if (req.files && req.files.length > 0) {
      const mediaData = req.files.map(file => ({
        journalId: newJournal.id,
        mediaUrl: `/uploads/${file.filename}`, 
        mediaType: 'IMAGE'
      }));
      await prisma.journalMedia.createMany({ data: mediaData });
    }

    res.status(201).json({ 
      success: true, 
      message: "Jurnal berhasil disimpan ke Draft.", 
      data: newJournal 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal menyimpan draft jurnal." });
  }
};

// --- 2. READ & SEARCH: Ambil Semua Jurnal (Hanya PUBLISHED) ---
const getJournals = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const { locationId, themeTag, search } = req.query;

    const whereClause = {
      status: 'PUBLISHED' 
    };

    if (locationId) whereClause.locationId = locationId;
    if (themeTag) whereClause.themeTag = themeTag;
    
    // Fitur Search (Mencari berdasarkan kata kunci di konten)
    if (search) {
      whereClause.content = { contains: search }; 
    }

    const journals = await prisma.journal.findMany({
      where: whereClause,
      skip: skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { username: true } }, 
        location: { select: { name: true } },
        media: true 
      }
    });

    const totalData = await prisma.journal.count({ where: whereClause });
    const totalPages = Math.ceil(totalData / limit);

    res.status(200).json({
      success: true,
      pagination: { totalData, totalPages, currentPage: page, limitPerPage: limit },
      data: journals
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengambil data jurnal." });
  }
};

// --- TAMBAHAN BARU: UPDATE (Edit Jurnal) ---
const updateJournal = async (req, res) => {
  try {
    const { id } = req.params;
    const { content, themeTag } = req.body;

    const journal = await prisma.journal.findUnique({ where: { id } });
    if (!journal) return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    if (journal.userId !== req.user.id) {
      return res.status(403).json({ success: false, message: "Kamu tidak berhak mengedit jurnal ini!" });
    }

    const updatedJournal = await prisma.journal.update({
      where: { id },
      data: {
        ...(content && { content }),
        ...(themeTag && { themeTag })
      }
    });

    if (req.files && req.files.length > 0) {
      await prisma.journalMedia.deleteMany({ where: { journalId: id } });
      const mediaData = req.files.map(file => ({
        journalId: id,
        mediaUrl: `/uploads/${file.filename}`, 
        mediaType: 'IMAGE'
      }));
      await prisma.journalMedia.createMany({ data: mediaData });
    }

    res.status(200).json({ 
      success: true, 
      message: "Jurnal berhasil diperbarui!", 
      data: updatedJournal 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal memperbarui jurnal." });
  }
};

// --- 3. DELETE: Hapus Jurnal (Dengan Proteksi Sisipan) ---
const deleteJournal = async (req, res) => {
  try {
    const { id } = req.params; 

    const journal = await prisma.journal.findUnique({ 
      where: { id },
      include: { childJournals: true } 
    });
    
    if (!journal) {
      return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    }

    if (journal.userId !== req.user.id) {
      return res.status(403).json({ success: false, message: "Kamu tidak berhak menghapus jurnal ini!" });
    }

    if (journal.childJournals && journal.childJournals.length > 0) {
      // SOFT DELETE (HAPUS BENARAN TAPI MENINGGALKAN JEJAK)
      // Teks ditimpa dan foto dihapus. Status tetap PUBLISHED agar UI PlaceHub tidak patah.
      await prisma.journalMedia.deleteMany({ where: { journalId: id } });
      await prisma.journal.update({
        where: { id },
        data: {
          content: "[Jurnal ini telah ditarik oleh penulis]"
        }
      });
      
      return res.status(200).json({ 
        success: true, 
        message: "Jurnal dihapus, namun meninggalkan jejak karena sudah memiliki balasan." 
      });
    }

    // HARD DELETE
    await prisma.journal.delete({ where: { id } });

    if (journal.status === 'PUBLISHED') {
      await prisma.location.update({
        where: { id: journal.locationId },
        data: { journalCount: { decrement: 1 } }
      });
    }

    res.status(200).json({ success: true, message: "Jurnal berhasil dihapus permanen." });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal menghapus jurnal." });
  }
};

// --- 3.5. ARCHIVE: Gembok Jurnal (Mode Instagram) ---
const archiveJournal = async (req, res) => {
  try {
    const { id } = req.params; 

    const journal = await prisma.journal.findUnique({ where: { id } });
    
    if (!journal) {
      return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    }

    if (journal.userId !== req.user.id) {
      return res.status(403).json({ success: false, message: "Kamu tidak berhak mengarsipkan jurnal ini!" });
    }

    if (journal.status === 'PRIVATE_ARCHIVE') {
      return res.status(400).json({ success: false, message: "Jurnal ini sudah diarsipkan." });
    }

    // ARCHIVE: Teks dan foto TETAP UTUH di database. Hanya status yang berubah.
    await prisma.journal.update({
      where: { id },
      data: { status: 'PRIVATE_ARCHIVE' }
    });

    // Jika sebelumnya PUBLISHED, kita kurangi pendaran cahaya di peta
    if (journal.status === 'PUBLISHED') {
      await prisma.location.update({
        where: { id: journal.locationId },
        data: { journalCount: { decrement: 1 } }
      });
    }

    res.status(200).json({ success: true, message: "Jurnal berhasil diarsipkan secara privat." });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengarsipkan jurnal." });
  }
};

// =====================================================================
// FASE 3: FUNGSI SYNC & PUBLISH MANUAL (HYBRID OFFLINE-ONLINE)
// =====================================================================

// --- 4. READ DRAFTS ---
const getDrafts = async (req, res) => {
  try {
    const userId = req.user.id;
    const drafts = await prisma.journal.findMany({
      where: { userId: userId, status: 'DRAFT' },
      orderBy: { createdAt: 'desc' },
      include: {
        location: { select: { name: true } },
        media: true
      }
    });

    res.status(200).json({ success: true, data: drafts });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengambil daftar draf." });
  }
};

// --- 5. PUBLISH ---
const publishJournal = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const journal = await prisma.journal.findUnique({ 
      where: { id },
      include: { location: true } 
    });

    if (!journal) return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    if (journal.userId !== userId) return res.status(403).json({ success: false, message: "Akses ditolak." });
    if (journal.status === 'PUBLISHED') return res.status(400).json({ success: false, message: "Jurnal ini sudah tayang!" });

    const validation = checkGeofence(
      parseFloat(journal.latitudeCaptured),
      parseFloat(journal.longitudeCaptured),
      parseFloat(journal.location.latitude),
      parseFloat(journal.location.longitude),
      journal.location.geofenceRadius
    );

    if (!validation.isValid) {
      return res.status(403).json({ 
        success: false, 
        message: `Validasi gagal. Jarak Anda (${Math.round(validation.distance)}m) terlalu jauh dari batas maksimum (${journal.location.geofenceRadius + 50}m).` 
      });
    }

    let successMessage = "Jurnal berhasil dipublikasikan! Kamu mendapat stempel lokasi.";
    if (validation.isWarning) {
      successMessage = `Jurnal dipublikasikan. (Peringatan: GPS Anda meleset ${Math.round(validation.distance)}m, masuk zona toleransi).`;
    }

    const updatedJournal = await prisma.journal.update({
      where: { id },
      data: { status: 'PUBLISHED' }
    });

    await applyPublishSideEffects(userId, journal.locationId);

    res.status(200).json({ 
      success: true, 
      message: successMessage, 
      data: updatedJournal 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mempublikasikan jurnal." });
  }
};

// --- 6. SYNC BATCH ---
const syncJournals = async (req, res) => {
  try {
    const userId = req.user.id;
    const { drafts } = req.body; 

    const insertedCount = await processBatchSync(userId, drafts);

    res.status(201).json({ 
      success: true, 
      message: `${insertedCount} draf berhasil disinkronisasi.` 
    });
  } catch (error) {
    if (error.message === "INVALID_DATA") {
      return res.status(400).json({ success: false, message: "Data draf kosong atau tidak valid." });
    }
    if (error.message === "FAKE_GPS_DETECTED") {
      return res.status(403).json({ success: false, message: "Sinkronisasi ditolak. Fake GPS terdeteksi pada salah satu draf." });
    }
    if (error.message === "EMPTY_CONTENT") {
      return res.status(400).json({ success: false, message: "Sinkronisasi ditolak. Ada draf dengan konten kosong." });
    }
    if (error.message === "INVALID_COORDINATES") {
      return res.status(400).json({ success: false, message: "Sinkronisasi ditolak. Koordinat tidak valid (NaN)." });
    }
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal sinkronisasi draf." });
  }
};

// =====================================================================
// FASE 7: FITUR MODERASI (REPORT)
// =====================================================================

// --- 7. REPORT ---
const reportJournal = async (req, res) => {
  try {
    const { id } = req.params;

    const journal = await prisma.journal.findUnique({ where: { id } });
    if (!journal) {
      return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    }

    if (journal.userId === req.user.id) {
      return res.status(400).json({ success: false, message: "Kamu tidak bisa melaporkan jurnalmu sendiri." });
    }

    await prisma.journal.update({
      where: { id },
      data: { reportCount: { increment: 1 } }
    });

    res.status(200).json({ 
      success: true, 
      message: "Laporan berhasil dikirim. Terima kasih telah menjaga komunitas tetap aman!" 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: "Gagal mengirim laporan." });
  }
};

// Export semua 8 fungsi agar bisa dipakai di journalRoutes.js
module.exports = { 
  createJournal, 
  getJournals,
  updateJournal, 
  deleteJournal, 
  archiveJournal,
  getDrafts, 
  publishJournal, 
  syncJournals,
  reportJournal 
};