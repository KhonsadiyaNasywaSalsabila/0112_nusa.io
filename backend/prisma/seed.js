const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

async function main() {
  console.log("Menjalankan Seeder...");

  // 1. Buat Super Admin Default
  const adminEmail = 'admin@nusa.io';
  const existingAdmin = await prisma.admin.findUnique({ where: { email: adminEmail } });

  if (!existingAdmin) {
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash('AdminNusa123!', salt);
    
    await prisma.admin.create({
      data: {
        username: 'superadmin',
        email: adminEmail,
        passwordHash: passwordHash,
        role: 'SUPER_ADMIN'
      }
    });
    console.log("✅ Super Admin berhasil dibuat! (admin@nusa.io / AdminNusa123!)");
  } else {
    console.log("⚠️ Super Admin sudah ada.");
  }

  // 2. Buat Default Moderator
  const modEmail = 'moderator@nusa.io';
  const existingMod = await prisma.admin.findUnique({ where: { email: modEmail } });

  if (!existingMod) {
    const passwordHash = await bcrypt.hash('ModNusa123!', 10);
    await prisma.admin.create({
      data: {
        username: 'moderator1',
        email: modEmail,
        passwordHash: passwordHash,
        role: 'MODERATOR'
      }
    });
    console.log("✅ Moderator berhasil dibuat! (moderator@nusa.io / ModNusa123!)");
  } else {
    console.log("⚠️ Moderator sudah ada.");
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
