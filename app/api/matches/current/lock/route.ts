
import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../_utils/prisma';
import { getChannelId, requireAdmin } from '../../../_utils/auth';

export async function POST(req: NextRequest) {
  const unauthorized = requireAdmin(req);
  if (unauthorized) return unauthorized;

  const channelId = getChannelId(req);
  const match = await prisma.match.findFirst({ where: { channelId, state: 'OPEN' }, orderBy: { openedAt: 'desc' } });
  if (!match) return NextResponse.json({ error: 'no open match' }, { status: 404 });

  await prisma.match.update({ where: { id: match.id }, data: { state: 'LOCKED' } });
  return NextResponse.json({ ok: true });
}
