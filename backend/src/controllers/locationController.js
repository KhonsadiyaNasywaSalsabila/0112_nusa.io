const prisma = require('../config/prisma');

// --- Ambil Semua Lokasi (Tamu & User) ---
const getLocations = async (req, res) => {
  try {
    // 1. Deteksi siapa yang akses (berkat optionalAuth)
    const userId = req.user ? req.user.id : null;

    // 2. Tarik data lokasi + hitung jurnal (KODE ASLIMU YANG KEREN)
    const locations = await prisma.location.findMany({
      include: {
        _count: {
          select: { journals: true }
        }
      }
    });

    // 3. Tarik data bookmark dan stempel JIKA yang akses adalah User Login
    let userBookmarks = [];
    let userStamps = [];
    if (userId) {
      userBookmarks = await prisma.userBookmarkLocation.findMany({
        where: { userId: userId }
      });
      userStamps = await prisma.userStamp.findMany({
        where: { userId: userId }
      });
    }

    // 4. Format Ulang Datanya agar lebih rapi saat dibaca Flutter
    const formattedLocations = locations.map(loc => {
      // Cek apakah ID lokasi ini ada di dalam daftar bookmark si User
      const isBookmarked = userBookmarks.some(b => b.locationId === loc.id);
      const isVisited = userStamps.some(s => s.locationId === loc.id);

      return {
        id: loc.id,
        name: loc.name,
        description: loc.description || "",
        latitude: Number(loc.latitude),
        longitude: Number(loc.longitude),
        geofenceRadius: Number(loc.geofenceRadius),
        journalCount: loc._count.journals,
        isBookmarked: isBookmarked,
        isVisited: isVisited
      };
    });

    res.status(200).json({ 
      success: true, 
      message: userId ? "Memuat peta (Pengguna Terdaftar)" : "Memuat peta (Tamu)",
      data: formattedLocations 
    });

  } catch (error) {
    console.error("Error getLocations:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data lokasi dari database." });
  }
};

// --- Ambil Detail Lokasi + Jurnal PUBLISHED (Pusat Arsip Lokasi) ---
const getLocationJournals = async (req, res) => {
  try {
    const { id } = req.params;
    const { theme } = req.query;

    // Ambil info lokasi
    const location = await prisma.location.findUnique({
      where: { id },
      select: { id: true, name: true, latitude: true, longitude: true, geofenceRadius: true, coverPhotoUrl: true, description: true }
    });

    if (!location) {
      return res.status(404).json({ success: false, message: "Lokasi tidak ditemukan." });
    }

    const whereClause = {
      locationId: id,
      OR: [
        { status: 'PUBLISHED' },
        { status: 'PRIVATE_ARCHIVE', childJournals: { some: {} } }
      ]
    };

    if (theme && theme !== 'Semua') {
      whereClause.themeTag = theme;
    }

    // Ambil SEMUA jurnal di lokasi tersebut yang berstatus PUBLISHED atau PRIVATE_ARCHIVE (jika punya anak)
    const journalsData = await prisma.journal.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' }, // Urutkan terbaru
      include: {
        user: { select: { id: true, username: true, profilePhotoUrl: true } },
        media: true
      }
    });

    // Cek bookmark lokasi, jurnal, dan status kunjungan jika user login
    let isLocationBookmarked = false;
    let isLocationVisited = false;
    let savedJournalIds = [];
    
    if (req.user) {
      const userBookmark = await prisma.userBookmarkLocation.findUnique({
        where: { userId_locationId: { userId: req.user.id, locationId: id } }
      });
      isLocationBookmarked = !!userBookmark;

      const userStamp = await prisma.userStamp.findFirst({
        where: { userId: req.user.id, locationId: id }
      });
      isLocationVisited = !!userStamp;

      const savedJournals = await prisma.userSavedJournal.findMany({
        where: { userId: req.user.id, journalId: { in: journalsData.map(j => j.id) } },
        select: { journalId: true }
      });
      savedJournalIds = savedJournals.map(sj => sj.journalId);
    }
    
    const journals = journalsData.map(j => ({
      ...j,
      content: j.status === 'PRIVATE_ARCHIVE' ? "[Jurnal ini telah diarsipkan oleh penulis]" : j.content,
      media: j.status === 'PRIVATE_ARCHIVE' ? [] : j.media,
      isBookmarked: savedJournalIds.includes(j.id)
    }));

    // Tambahkan isBookmarked dan isVisited ke object location
    const locationWithBookmark = { 
      ...location, 
      isBookmarked: isLocationBookmarked,
      isVisited: isLocationVisited
    };

    res.status(200).json({
      success: true,
      message: "Berhasil memuat Pusat Arsip Lokasi",
      data: {
        location: locationWithBookmark,
        journals
      }
    });
  } catch (error) {
    console.error("Error getLocationJournals:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data arsip lokasi." });
  }
};

module.exports = { getLocations, getLocationJournals };