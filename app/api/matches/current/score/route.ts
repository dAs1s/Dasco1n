
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../_utils/prisma';
import { getChannelId, requireAdmin } from '../../../_utils/auth';

export async function POST(req: NextRequest) {
  const unauthorized = requireAdmin(req);
  if (unauthorized) return unauthorized;

  const channelId = getChannelId(req);
  const body = await req.json().catch(() => ({}));
  const p1Score = Number(body?.p1Score);
  const p2Score = Number(body?.p2Score);
  if (!Number.isInteger(p1Score) || !Number.isInteger(p2Score)) {
    return NextResponse.json({ error: 'p1Score and p2Score must be integers' }, { status: 400 });
  }

  const match = await prisma.match.findFirst({
    where: { channelId, NOT: { state: 'SETTLED' } },
    orderBy: { openedAt: 'desc' },
  });
  if (!match) return NextResponse.json({ error: 'no active match' }, { status: 404 });

  const updated = await prisma.match.update({
    where: { id: match.id },
    data: { scoreP1: p1Score, scoreP2: p2Score },
    select: { id: true, scoreP1: true, scoreP2: true },
  });

  return NextResponse.json({ ok: true, match: updated });
}
