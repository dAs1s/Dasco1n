// app/api/users/list/route.ts
import { NextResponse } from 'next/server';
import { prisma } from '@/server/db';

export async function GET() {
  try {
    const users = await prisma.user.findMany({
      orderBy: { username: 'asc' },
      select: { id: true, username: true, elo: true, wins: true, losses: true, twitchId: true, discordId: true },
    });
    return NextResponse.json({ users });
  } catch (err) {
    console.error('GET /api/users/list error:', err);
    return NextResponse.json({ error: 'internal error' }, { status: 500 });
  }
}
