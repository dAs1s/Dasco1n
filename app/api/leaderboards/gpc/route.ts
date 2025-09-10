
import { NextResponse } from 'next/server';
import { prisma } from '../../_utils/prisma';

export async function GET() {
  const gpc = await prisma.coin.findUnique({ where: { symbol: 'GPC' } });
  if (!gpc) return NextResponse.json({ error: 'GPC not found' }, { status: 500 });

  const rows = await prisma.wallet.findMany({
    where: { coinId: gpc.id },
    include: { user: true },
    orderBy: { balance: 'desc' },
    take: 100,
  });

  const items = rows.map((r, i) => ({ rank: i + 1, username: r.user.username, balance: Number(r.balance) }));
  return NextResponse.json({ items });
}
