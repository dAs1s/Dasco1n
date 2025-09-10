
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../_utils/prisma';
import { getChannelId, requireAdmin } from '../../../_utils/auth';
import { findUserByUsernameInsensitive } from '../../../_utils/users';

export async function POST(req: NextRequest) {
  const unauthorized = requireAdmin(req);
  if (unauthorized) return unauthorized;

  const channelId = getChannelId(req);
  const headerUsername = req.headers.get('x-username')?.trim();
  const body = await req.json().catch(() => ({}));
  const username = (headerUsername || body?.username || '').toString().trim();

  const choice = Number(body?.choice);
  const loserScore = Number(body?.loserScore);
  const amountDSC = Number(body?.amount);
  const replace = Boolean(body?.replace);

  if (!username) return NextResponse.json({ error: 'username required' }, { status: 400 });
  if (![1, 2].includes(choice)) return NextResponse.json({ error: 'choice must be 1 or 2' }, { status: 400 });
  if (!Number.isInteger(loserScore) || loserScore < 0 || loserScore > 9) {
    return NextResponse.json({ error: 'loserScore must be 0..9' }, { status: 400 });
  }
  if (!Number.isFinite(amountDSC) || amountDSC <= 0) {
    return NextResponse.json({ error: 'amount must be > 0' }, { status: 400 });
  }

  const user = await findUserByUsernameInsensitive(username);
  if (!user) return NextResponse.json({ error: 'user not found in database' }, { status: 404 });

  const match = await prisma.match.findFirst({ where: { channelId, state: 'OPEN' }, orderBy: { openedAt: 'desc' } });
  if (!match) return NextResponse.json({ error: 'no open match' }, { status: 409 });

  const predictedWinner = choice === 1 ? 'p1' : 'p2';
  const prev = await prisma.bet.findUnique({ where: { matchId_userId: { matchId: match.id, userId: user.id } } });

  if (prev && !replace) return NextResponse.json({ error: 'Bet already exists. Use replace:true.' }, { status: 409 });

  if (prev) {
    await prisma.bet.update({ where: { id: prev.id }, data: { predictedWinner, predictedLoserScore: loserScore, amountDSC, status: 'PENDING' } });
  } else {
    await prisma.bet.create({ data: { matchId: match.id, userId: user.id, predictedWinner, predictedLoserScore: loserScore, amountDSC, status: 'PENDING' } });
  }

  return NextResponse.json({ ok: true });
}
