
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../_utils/prisma';
import { getChannelId, requireAdmin } from '../../../_utils/auth';

export async function POST(req: NextRequest) {
  const unauthorized = requireAdmin(req);
  if (unauthorized) return unauthorized;

  const channelId = getChannelId(req);
  const { winner, loserScore } = await req.json();
  const w = Number(winner);
  if (![1,2].includes(w)) return NextResponse.json({ error: 'winner must be 1 or 2' }, { status: 400 });
  if (!Number.isInteger(loserScore) || loserScore < 0 || loserScore > 9) {
    return NextResponse.json({ error: 'loserScore must be 0..9' }, { status: 400 });
  }

  const match = await prisma.match.findFirst({ where: { channelId, state: 'LOCKED' }, orderBy: { openedAt: 'desc' } });
  if (!match) return NextResponse.json({ error: 'no locked match' }, { status: 404 });

  const [p1, p2] = await prisma.$transaction([
    prisma.user.findUnique({ where: { id: match.p1UserId } }),
    prisma.user.findUnique({ where: { id: match.p2UserId } }),
  ]);
  if (!p1 || !p2) return NextResponse.json({ error: 'players missing' }, { status: 500 });

  const predictedWinnerKey = w === 1 ? 'p1' : 'p2';
  const scoreP1 = w === 1 ? 10 : loserScore;
  const scoreP2 = w === 2 ? 10 : loserScore;

  const result = await prisma.$transaction(async (tx) => {
    await tx.match.update({
      where: { id: match.id },
      data: {
        state: 'SETTLED',
        settledAt: new Date(),
        scoreP1,
        scoreP2,
        loserScore,
        winner: predictedWinnerKey as any,
      },
    });

    const bets = await tx.bet.findMany({
      where: { matchId: match.id, status: 'PENDING' },
      select: { id: true, userId: true, predictedWinner: true, predictedLoserScore: true, amountDSC: true },
    });

    const winners = bets.filter(b => b.predictedWinner === predictedWinnerKey && b.predictedLoserScore === loserScore);
    const losers  = bets.filter(b => !(b.predictedWinner === predictedWinnerKey && b.predictedLoserScore === loserScore));

    const sum = (arr: typeof bets) => arr.reduce((t, b) => t + Number(b.amountDSC), 0);
    const winnersSum = sum(winners);
    const losersSum  = sum(losers);

    for (const b of winners) {
      const share = winnersSum > 0 ? (Number(b.amountDSC) / winnersSum) * losersSum : 0;
      const payout = Number(b.amountDSC) + share;
      await tx.bet.update({ where: { id: b.id }, data: { status: 'SETTLED', payoutDSC: payout } });
    }
    for (const b of losers) {
      await tx.bet.update({ where: { id: b.id }, data: { status: 'SETTLED', payoutDSC: 0 } });
    }

    // TODO: plug ELO update here using your elo.ts helper

    return { winners: winners.length, losers: losers.length };
  });

  return NextResponse.json({ ok: true, ...result });
}
