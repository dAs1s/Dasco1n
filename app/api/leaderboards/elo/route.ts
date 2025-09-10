
import { NextResponse } from 'next/server';
import { prisma } from '../../_utils/prisma';

export async function GET() {
  const top = await prisma.user.findMany({ orderBy: { elo: 'desc' }, take: 100, select: { username: true, elo: true } });
  const items = top.map((u, i) => ({ rank: i + 1, username: u.username, elo: u.elo }));
  return NextResponse.json({ items });
}
