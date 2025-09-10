
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../_utils/prisma';
import { requireAdmin } from '../../_utils/auth';
import { findUserByUsernameInsensitive } from '../../_utils/users';

export async function POST(req: NextRequest) {
  const unauthorized = requireAdmin(req);
  if (unauthorized) return unauthorized;

  const body = await req.json().catch(() => ({}));
  const p1Name = (body?.p1 ?? '').toString().trim();
  const p2Name = (body?.p2 ?? '').toString().trim();
  const channelId = (body?.channelId ?? 'default').toString().trim();

  if (!p1Name || !p2Name) return NextResponse.json({ error: 'p1 and p2 are required' }, { status: 400 });
  if (p1Name.toLowerCase() === p2Name.toLowerCase()) return NextResponse.json({ error: 'p1 and p2 must differ' }, { status: 400 });

  const [p1, p2] = await Promise.all([
    findUserByUsernameInsensitive(p1Name),
    findUserByUsernameInsensitive(p2Name),
  ]);
  if (!p1 || !p2) return NextResponse.json({ error: 'player not found in database' }, { status: 404 });

  const existingOpen = await prisma.match.findFirst({ where: { channelId, state: 'OPEN' }, orderBy: { openedAt: 'desc' } });
  if (existingOpen) await prisma.match.update({ where: { id: existingOpen.id }, data: { state: 'SETTLED', settledAt: new Date() } });

  const created = await prisma.match.create({
    data: { channelId, p1UserId: p1.id, p2UserId: p2.id, state: 'OPEN', openedAt: new Date(), scoreP1: 0, scoreP2: 0 },
  });

  return NextResponse.json({ ok: true, match: { id: created.id, channelId, state: created.state } }, { status: 201 });
}
