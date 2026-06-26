const prisma = require('../config/prisma');

// --- Ambil Data Peta (Tamu & User) ---
const getMapData = async (req, res) => {
  try {
    // 1. Deteksi user login jika ada (Satpam Santai)
    const userId = req.user ? req.user.id : null;

    // 2. Tarik data lokasi beserta jurnal yang berstatus PUBLISHED
    const locations = await prisma.location.findMany({
      where: { isActive: true },
      include: {
        journals: {
          where: { 
            OR: [
              { status: 'PUBLISHED' },
              { status: 'PRIVATE_ARCHIVE', childJournals: { some: {} } }
            ]
          },
          include: {
            user: {
              select: { id: true, username: true, profilePhotoUrl: true }
            },
            media: true
          },
          orderBy: {
            createdAt: 'desc'
          }
        }
      }
    });

    // 3. Tarik data bookmark JIKA yang akses adalah User Login
    let userBookmarks = [];
    if (userId) {
      userBookmarks = await prisma.userBookmarkLocation.findMany({
        where: { userId: userId }
      });
    }

    // 4. Format Ulang Datanya dengan Agregasi Tema Dinamis
    const formattedLocations = locations.map(loc => {
      // Cek apakah ID lokasi ini ada di dalam daftar bookmark si User
      const isBookmarked = userBookmarks.some(b => b.locationId === loc.id);

      // Ekstrak semua tema dari jurnal-jurnal PUBLISHED di lokasi ini
      const themes = loc.journals.map(j => j.themeTag);
      // Buat array tema unik (Distinct)
      const availableThemes = [...new Set(themes)];

      // Hitung jumlah jurnal PUBLISHED (Glow Effect hanya untuk yang benar-benar aktif)
      const publishedCount = loc.journals.filter(j => j.status === 'PUBLISHED').length;

      return {
        id: loc.id,
        name: loc.name,
        description: loc.description || "",
        latitude: Number(loc.latitude), 
        longitude: Number(loc.longitude),
        coverPhotoUrl: loc.coverPhotoUrl,
        geofenceRadius: Number(loc.geofenceRadius),
        journalCount: publishedCount > 0 ? publishedCount : loc.journalCount, // Fallback ke total jurnal jika belum sinkron
        availableThemes: availableThemes, // Array tema dinamis, misal: ['KULINER', 'VINTAGE']
        isBookmarked: isBookmarked,
        journals: loc.journals.map(j => ({
          id: j.id,
          content: j.status === 'PRIVATE_ARCHIVE' ? "[Jurnal ini telah diarsipkan oleh penulis]" : j.content,
          themeTag: j.themeTag,
          createdAt: j.createdAt,
          user: j.user,
          media: j.status === 'PRIVATE_ARCHIVE' ? null : (j.media.length > 0 ? j.media[0] : null) 
        }))
      };
    });

    res.status(200).json({ 
      success: true, 
      message: userId ? "Memuat peta (Pengguna Terdaftar)" : "Memuat peta (Tamu)",
      data: formattedLocations 
    });

  } catch (error) {
    console.error("Error getMapData:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data peta eksplorasi." });
  }
};

module.exports = { getMapData };
