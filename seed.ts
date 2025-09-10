import { PrismaClient } from "@prisma/client";
import Decimal from "decimal.js";

const prisma = new PrismaClient();

async function main() {
  // DSC (tier 0)
  const dsc = await prisma.coin.upsert({
    where: { symbol: "DSC" },
    update: {},
    create: {
      symbol: "DSC",
      name: "Dascoin",
      tier: 0,
      decimals: 0,
      basePrice: new Decimal(1).toString(),
      logoUrl: "/coins/dsc.png",
      market: {
        create: {
          hmEnabled: false,
          hmValue: new Decimal(1).toString(),
          overrideEnabled: true,
          overridePrice: new Decimal(1).toString(),
        },
      },
    },
  });

  // GPC (tier 1)
  const gpc = await prisma.coin.upsert({
    where: { symbol: "GPC" },
    update: {},
    create: {
      symbol: "GPC",
      name: "GlorpCoin",
      tier: 1,
      decimals: 4,
      basePrice: new Decimal(4000).toString(), // will be replaced by price provider if not override
      logoUrl: "/coins/gpc.png",
      market: {
        create: {
          hmEnabled: false,
          hmValue: new Decimal(1).toString(),
          overrideEnabled: process.env.GPC_PRICE_OVERRIDE_ENABLED === "true",
          overridePrice: new Decimal(process.env.GPC_PRICE_OVERRIDE || "4000").toString(),
        },
      },
    },
  });

  console.log({ dsc, gpc });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
