const prisma = require('../config/prisma');

const getUserStamps = async (req, res) => {
  try {
    const userId = req.user.id;

    // Menarik stempel beserta detail lokasi
    const stamps = await prisma.userStamp.findMany({
      where: { userId: userId },
      include: {
        location: {
          select: {
            id: true,
            name: true,
            coverPhotoUrl: true,
            latitude: true,
            longitude: true
          }
        }
      },
      orderBy: { earnedAt: 'desc' }
    });

    res.status(200).json({
      success: true,
      message: "Berhasil memuat stempel pengguna",
      data: stamps
    });
  } catch (error) {
    console.error("Error getUserStamps:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data stempel." });
  }
};

const getUserArchives = async (req, res) => {
  try {
    const userId = req.user.id;

    const archives = await prisma.journal.findMany({
      where: {
        userId: userId,
        status: 'PRIVATE_ARCHIVE'
      },
      include: {
        location: {
          select: { name: true }
        },
        media: true
      },
      orderBy: { createdAt: 'desc' }
    });

    res.status(200).json({
      success: true,
      message: "Berhasil memuat arsip pribadi",
      data: archives
    });
  } catch (error) {
    console.error("Error getUserArchives:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data arsip." });
  }
};

const getUserMemories = async (req, res) => {
  try {
    const userId = req.user.id;
    const memories = await prisma.journal.findMany({
      where: {
        userId: userId,
        status: 'PUBLISHED'
      },
      include: {
        location: {
          select: { name: true, isActive: true }
        },
        media: true
      },
      orderBy: { createdAt: 'desc' }
    });
    res.status(200).json({ success: true, data: memories });
  } catch (error) {
    console.error("Error getUserMemories:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data memori." });
  }
};

module.exports = { getUserStamps, getUserArchives, getUserMemories };
