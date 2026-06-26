const prisma = require('../config/prisma');

// --- A. Ekstrak Fungsi Geofence (Haversine Formula) ---
// Mengembalikan TRUE jika jarak masih di dalam radius yang diizinkan.
const checkGeofence = (lat1, lon1, lat2, lon2, radiusInMeters) => {
  const R = 6371e3; // Radius bumi dalam satuan meter
  const toRadians = (degree) => degree * (Math.PI / 180);

  const phi1 = toRadians(lat1);
  const phi2 = toRadians(lat2);
  const deltaPhi = toRadians(lat2 - lat1);
  const deltaLambda = toRadians(lon2 - lon1);

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;

  if (distance <= radiusInMeters) {
    return { isValid: true, isWarning: false, distance };
  } else if (distance <= radiusInMeters + 50) { // Grace buffer 50m
    return { isValid: true, isWarning: true, distance };
  } else {
    return { isValid: false, isWarning: false, distance };
  }
};

// --- B. Ekstrak Efek Samping Publikasi ---
// Dipanggil SAAT USER MENEKAN PUBLISH (Di Fase 3)
const applyPublishSideEffects = async (userId, locationId) => {
  
  // 1. Berikan Stempel Kehadiran (UserStamp)
  try {
    await prisma.userStamp.create({
      data: { userId, locationId }
    });
  } catch (error) {
    // =====================================================================
    // KUNCI UTAMA FASE 5: Race Condition — Stamp
    // Diam-diam skip kalau P2002 (Unique Constraint) terjadi
    // =====================================================================
    if (error.code === 'P2002') {
      // Kita cetak log di server saja buat info admin/developer, 
      // tapi JANGAN di-throw agar tidak bikin controller crash.
      console.log(`[Info] User ${userId} mempublikasikan jurnal di lokasi ${locationId} lagi. Stempel ganda diabaikan.`);
    } else {
      // Kalau errornya BUKAN karena duplikat (misal: database mati), lempar ke controller.
      throw error; 
    }
  }

  // 2. Tambah jumlah jurnal di tabel Location (+1)
  await prisma.location.update({
    where: { id: locationId },
    data: { journalCount: { increment: 1 } }
  });

  // 3. Ubah status Bookmark menjadi VISITED (jika user pernah merencanakan ini)
  await prisma.userBookmarkLocation.updateMany({
    where: { 
      userId: userId, 
      locationId: locationId, 
      status: 'PLANNED' 
    },
    data: { status: 'VISITED' }
  });
};

module.exports = { checkGeofence, applyPublishSideEffects };