const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const journals = await prisma.journal.findMany({
    include: { media: true },
    orderBy: { createdAt: 'desc' },
    take: 5
  });
  console.log(JSON.stringify(journals, null, 2));
}

main()
  .catch(e => console.error(e))
  .finally(async () => await prisma.$disconnect());
