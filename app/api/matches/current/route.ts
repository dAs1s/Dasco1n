
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../_utils/prisma';
import { getChannelId } from '../../_utils/auth';

export async function GET(req: NextRequest) {
  try {
    const channelId = getChannelId(req);
    const match = await prisma.match.findFirst({
      where: { channelId, NOT: { state: 'SETTLED' } },
      orderBy: { openedAt: 'desc' },
    });
    if (!match) return NextResponse.json({ match: null });

    const [p1, p2] = await prisma.$transaction([
      prisma.user.findUnique({ where: { id: match.p1UserId } }),
      prisma.user.findUnique({ where: { id: match.p2UserId } }),
    ]);

    const [sumP1, sumP2] = await prisma.$transaction([
      prisma.bet.aggregate({ _sum: { amountDSC: true }, where: { matchId: match.id, predictedWinner: 'p1' } }),
      prisma.bet.aggregate({ _sum: { amountDSC: true }, where: { matchId: match.id, predictedWinner: 'p2' } }),
    ]);

    return NextResponse.json({
      match: {
        id: match.id,
        channelId: match.channelId,
        state: match.state,
        p1: { id: p1?.id, name: p1?.username, pfpUrl: (p1 as any)?.pfpUrl ?? null },
        p2: { id: p2?.id, name: p2?.username, pfpUrl: (p2 as any)?.pfpUrl ?? null },
        scoreP1: match.scoreP1 ?? 0,
        scoreP2: match.scoreP2 ?? 0,
        totals: {
          p1: (sumP1._sum.amountDSC ?? 0).toString(),
          p2: (sumP2._sum.amountDSC ?? 0).toString(),
        },
        openedAt: match.openedAt,
      },
    });
  } catch (err: any) {
    console.error('GET /api/matches/current error:', err);
    return NextResponse.json({ error: err?.message || 'internal error' }, { status: 500 });
  }
}
