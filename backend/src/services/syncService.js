const prisma = require('../config/prisma');

// --- Fungsi untuk memproses data sinkronisasi rombongan (Batch) ---
const processBatchSync = async (userId, drafts) => {
  if (!drafts || !Array.isArray(drafts) || drafts.length === 0) {
    throw new Error("INVALID_DATA");
  }

  let successCount = 0;

  // Gunakan transaksi agar jika gagal di tengah jalan tidak ada data setengah matang
  await prisma.$transaction(async (tx) => {
    for (const d of drafts) {
      if (d.isMocked) {
        throw new Error("FAKE_GPS_DETECTED");
      }
      if (!d.content || d.content.trim() === '') {
        throw new Error("EMPTY_CONTENT");
      }
      const lat = parseFloat(d.latitudeCaptured);
      const lng = parseFloat(d.longitudeCaptured);
      if (isNaN(lat) || isNaN(lng)) {
        throw new Error("INVALID_COORDINATES");
      }

      // 1. Buat Journal
      const journal = await tx.journal.create({
        data: {
          userId: userId,
          locationId: d.locationId,
          content: d.content,
          themeTag: d.themeTag,
          latitudeCaptured: parseFloat(d.latitudeCaptured),
          longitudeCaptured: parseFloat(d.longitudeCaptured),
          status: 'DRAFT', // Kunci rapat: Hanya boleh DRAFT
          rootJournalId: d.rootJournalId || null
        }
      });

      // 2. Hubungkan Media jika ada
      if (d.mediaUrls && Array.isArray(d.mediaUrls) && d.mediaUrls.length > 0) {
        const mediaData = d.mediaUrls.map(url => ({
          journalId: journal.id,
          mediaUrl: url,
          mediaType: 'IMAGE'
        }));
        await tx.journalMedia.createMany({
          data: mediaData
        });
      }

      successCount++;
    }
  });

  return successCount; // Kembalikan jumlah data yang berhasil masuk
};

module.exports = { processBatchSync };