import { prisma } from "@/src/lib/prisma";

export async function currentOpenMatch(channelId?: string) {
  if (!channelId) throw new Error("channelId required");
  const match = await prisma.match.findFirst({ where: { channelId, state: "OPEN" }, orderBy: { openedAt: "desc" } });
  if (!match) throw new Error("No OPEN match");
  const bets = await prisma.bet.findMany({ where: { matchId: match.id, status: "PLACED" } });
  const totals = bets.reduce((acc, b) => {
    if (b.predictedWinner === "p1") acc.p1 += b.amountDSC; else acc.p2 += b.amountDSC;
    return acc;
  }, { p1: 0, p2: 0 } as { p1: number; p2: number });
  return { match, totals };
}
