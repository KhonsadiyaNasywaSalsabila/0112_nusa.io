const prisma = require('../config/prisma');

const getUserStamps = async (req, res) => {
  try {
    const userId = req.user.id;
    const search = req.query.search;

    let whereClause = { userId: userId };

    if (search && search.trim() !== '') {
      whereClause.location = {
        name: { contains: search }
      };
    }

    // Menarik stempel beserta detail lokasi
    const stamps = await prisma.userStamp.findMany({
      where: whereClause,
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
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 5;
    const skip = (page - 1) * limit;

    const theme = req.query.theme;
    const search = req.query.search;

    let whereClause = {
      userId: userId,
      status: 'PRIVATE_ARCHIVE'
    };

    if (theme && theme !== 'Semua') {
      whereClause.themeTag = theme;
    }

    if (search && search.trim() !== '') {
      whereClause.OR = [
        { content: { contains: search } },
        { location: { name: { contains: search } } }
      ];
    }

    const totalItems = await prisma.journal.count({
      where: whereClause
    });

    const archives = await prisma.journal.findMany({
      where: whereClause,
      include: {
        location: {
          select: { name: true }
        },
        media: true
      },
      orderBy: { createdAt: 'desc' },
      skip: skip,
      take: limit
    });

    res.status(200).json({
      success: true,
      message: "Berhasil memuat arsip pribadi",
      data: archives,
      meta: {
        totalItems,
        currentPage: page,
        hasNextPage: skip + archives.length < totalItems
      }
    });
  } catch (error) {
    console.error("Error getUserArchives:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data arsip." });
  }
};

const getUserMemories = async (req, res) => {
  try {
    const userId = req.user.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 5;
    const skip = (page - 1) * limit;

    const theme = req.query.theme;
    const search = req.query.search;

    let whereClause = {
      userId: userId,
      status: 'PUBLISHED'
    };

    if (theme && theme !== 'Semua') {
      whereClause.themeTag = theme;
    }

    if (search && search.trim() !== '') {
      whereClause.OR = [
        { content: { contains: search } },
        { location: { name: { contains: search } } }
      ];
    }

    const totalItems = await prisma.journal.count({
      where: whereClause
    });

    const memories = await prisma.journal.findMany({
      where: whereClause,
      include: {
        location: {
          select: { name: true, isActive: true }
        },
        media: true,
        _count: {
          select: { childJournals: true }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip: skip,
      take: limit
    });
    res.status(200).json({ 
      success: true, 
      data: memories,
      meta: {
        totalItems,
        currentPage: page,
        hasNextPage: skip + memories.length < totalItems
      }
    });
  } catch (error) {
    console.error("Error getUserMemories:", error);
    res.status(500).json({ success: false, message: "Gagal mengambil data memori." });
  }
};

module.exports = { getUserStamps, getUserArchives, getUserMemories };
