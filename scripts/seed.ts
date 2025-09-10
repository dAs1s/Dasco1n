import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  const users = ["playerA","playerB"];
  for (const username of users) {
    await prisma.user.upsert({
      where: { username },
      update: {},
      create: { username },
    });
  }
  console.log("Seeded users:", users.join(", "));
}
main().finally(() => prisma.$disconnect());
