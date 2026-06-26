const prisma = require('../config/prisma');

// ==========================================
// 1. RENCANA JELAJAH (BOOKMARK LOKASI)
// ==========================================

const bookmarkLocation = async (req, res) => {
  try {
    const userId = req.user.id;
    const { locationId } = req.body;

    if (!locationId) {
      return res.status(400).json({ success: false, message: "Location ID wajib diisi." });
    }

    const location = await prisma.location.findUnique({ where: { id: locationId } });
    if (!location) {
      return res.status(404).json({ success: false, message: "Lokasi tidak ditemukan." });
    }

    const existingStamp = await prisma.userStamp.findFirst({
      where: { userId, locationId }
    });

    const status = existingStamp ? 'VISITED' : 'PLANNED';

    const newBookmark = await prisma.userBookmarkLocation.create({
      data: { userId, locationId, status }
    });

    return res.status(201).json({ success: true, message: "Berhasil ditambahkan ke Rencana Jelajah!", data: newBookmark });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, message: "Lokasi ini sudah ada di Rencana Jelajahmu!" });
    }
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menyimpan lokasi." });
  }
};

const getBookmarkedLocations = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;
    const search = req.query.search;

    const whereClause = { userId: req.user.id };

    if (search && search.trim() !== '') {
      whereClause.location = {
        OR: [
          { name: { contains: search } },
          { description: { contains: search } }
        ]
      };
    }

    const totalItems = await prisma.userBookmarkLocation.count({
      where: whereClause
    });

    const bookmarks = await prisma.userBookmarkLocation.findMany({
      where: whereClause,
      include: { location: true },
      orderBy: { createdAt: 'desc' },
      skip: skip,
      take: limit
    });
    
    return res.status(200).json({ 
      success: true, 
      data: bookmarks,
      meta: {
        totalItems,
        currentPage: page,
        hasNextPage: skip + bookmarks.length < totalItems
      }
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal mengambil daftar lokasi." });
  }
};

const removeBookmarkedLocation = async (req, res) => {
  try {
    const { id } = req.params;
    const bookmark = await prisma.userBookmarkLocation.findUnique({ where: { id } });
    
    if (!bookmark) return res.status(404).json({ success: false, message: "Rencana jelajah tidak ditemukan." });
    if (bookmark.userId !== req.user.id) return res.status(403).json({ success: false, message: "Akses ditolak." });

    await prisma.userBookmarkLocation.delete({ where: { id } });
    return res.status(200).json({ success: true, message: "Lokasi dihapus dari rencana jelajah." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menghapus rencana jelajah." });
  }
};

const removeBookmarkedLocationByLocationId = async (req, res) => {
  try {
    const { locationId } = req.params;
    const userId = req.user.id;
    
    const bookmark = await prisma.userBookmarkLocation.findUnique({
      where: { userId_locationId: { userId, locationId } }
    });
    
    if (!bookmark) return res.status(404).json({ success: false, message: "Rencana jelajah tidak ditemukan." });

    await prisma.userBookmarkLocation.delete({
      where: { userId_locationId: { userId, locationId } }
    });
    return res.status(200).json({ success: true, message: "Lokasi dihapus dari rencana jelajah." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menghapus rencana jelajah." });
  }
};

// ==========================================
// 2. KOLEKSI / INSPIRASI (SIMPAN JURNAL)
// ==========================================

const saveJournal = async (req, res) => {
  try {
    const userId = req.user.id;
    const { journalId } = req.body;

    if (!journalId) {
      return res.status(400).json({ success: false, message: "Journal ID wajib diisi." });
    }

    const journal = await prisma.journal.findUnique({ where: { id: journalId } });
    if (!journal) {
      return res.status(404).json({ success: false, message: "Jurnal tidak ditemukan." });
    }

    const newSave = await prisma.userSavedJournal.create({
      data: { userId, journalId }
    });

    return res.status(201).json({ success: true, message: "Jurnal berhasil disimpan ke Koleksi!", data: newSave });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({ success: false, message: "Jurnal ini sudah ada di Koleksimu!" });
    }
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menyimpan jurnal." });
  }
};

const getSavedJournals = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 5;
    const skip = (page - 1) * limit;
    const search = req.query.search;

    const whereClause = { userId: req.user.id };

    if (search && search.trim() !== '') {
      whereClause.journal = {
        OR: [
          { content: { contains: search } },
          { location: { name: { contains: search } } }
        ]
      };
    }

    const totalItems = await prisma.userSavedJournal.count({
      where: whereClause
    });

    const saves = await prisma.userSavedJournal.findMany({
      where: whereClause,
      include: {
        journal: {
          include: { user: { select: { username: true } }, location: { select: { name: true } }, media: true }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: skip,
      take: limit
    });

    return res.status(200).json({ 
      success: true, 
      data: saves,
      meta: {
        totalItems,
        currentPage: page,
        hasNextPage: skip + saves.length < totalItems
      }
    });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal mengambil daftar jurnal tersimpan." });
  }
};

const unsaveJournal = async (req, res) => {
  try {
    const { id } = req.params;
    const save = await prisma.userSavedJournal.findUnique({ where: { id } });
    
    if (!save) return res.status(404).json({ success: false, message: "Jurnal tersimpan tidak ditemukan." });
    if (save.userId !== req.user.id) return res.status(403).json({ success: false, message: "Akses ditolak." });

    await prisma.userSavedJournal.delete({ where: { id } });
    return res.status(200).json({ success: true, message: "Jurnal dihapus dari koleksi." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menghapus jurnal dari koleksi." });
  }
};

const unsaveJournalByJournalId = async (req, res) => {
  try {
    const { journalId } = req.params;
    const userId = req.user.id;
    
    const save = await prisma.userSavedJournal.findUnique({
      where: { userId_journalId: { userId, journalId } }
    });
    
    if (!save) return res.status(404).json({ success: false, message: "Jurnal tersimpan tidak ditemukan." });

    await prisma.userSavedJournal.delete({
      where: { userId_journalId: { userId, journalId } }
    });
    return res.status(200).json({ success: true, message: "Jurnal dihapus dari koleksi." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ success: false, message: "Gagal menghapus jurnal dari koleksi." });
  }
};

module.exports = {
  bookmarkLocation, getBookmarkedLocations, removeBookmarkedLocation, removeBookmarkedLocationByLocationId,
  saveJournal, getSavedJournals, unsaveJournal, unsaveJournalByJournalId
};