
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
  if (!username) return NextResponse.json({ error: 'username required' }, { status: 400 });

  const user = await findUserByUsernameInsensitive(username);
  if (!user) return NextResponse.json({ error: 'user not found in database' }, { status: 404 });

  const match = await prisma.match.findFirst({ where: { channelId, state: 'OPEN' }, orderBy: { openedAt: 'desc' } });
  if (!match) return NextResponse.json({ error: 'no open match' }, { status: 404 });

  const bet = await prisma.bet.findUnique({ where: { matchId_userId: { matchId: match.id, userId: user.id } } });
  if (!bet) return NextResponse.json({ error: 'no bet' }, { status: 404 });

  await prisma.bet.update({ where: { id: bet.id }, data: { status: 'REFUNDED' } });
  return NextResponse.json({ ok: true });
}
