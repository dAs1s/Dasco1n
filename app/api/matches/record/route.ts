import { NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

function json(data: any, status = 200) {
  return NextResponse.json(data, { status });
}
function bad(message: string, status = 400) {
  return json({ error: message }, status);
}

// Classic Elo helpers
function expectedScore(rA: number, rB: number) {
  return 1 / (1 + Math.pow(10, (rB - rA) / 400));
}
function updateElo(ra: number, rb: number, scoreA: 0 | 1, K: number) {
  const ea = expectedScore(ra, rb);
  const deltaA = K * (scoreA - ea);
  const newA = Math.round(ra + deltaA);
  const newB = Math.round(rb - deltaA);
  return { newA, newB, deltaA: Math.round(newA - ra), deltaB: Math.round(newB - rb) };
}

export async function POST(req: Request) {
  // Admin guard
  const hdrName = process.env.API_AUTH_HEADER ?? "x-admin-key";
  const expected = process.env.API_AUTH_TOKEN ?? "";
  if (expected) {
    const provided = req.headers.get(hdrName) ?? "";
    if (provided !== expected) return bad("unauthorized", 401);
  }

  let body: any;
  try { body = await req.json(); } catch { return bad("invalid json"); }

  // Your original !record format: !record <p1> <p2> <loserScore>
  // We treat p1 as the winner (to match your legacy behavior).
  let { p1, p2, loserScore, openedBy = "discord:unknown", channelId = "discord" } = body ?? {};
  if (!p1 || !p2 || (loserScore === undefined || loserScore === null)) return bad("missing p1, p2, loserScore");
  if (typeof p1 !== "string" || typeof p2 !== "string") return bad("p1 and p2 must be strings");

  p1 = String(p1).trim(); p2 = String(p2).trim();
  if (!p1 || !p2 || p1.toLowerCase() === p2.toLowerCase()) return bad("invalid players (empty or same)");

  const ls = Math.max(0, Math.min(9, Math.floor(Number(loserScore))));
  const now = new Date();
  const K = Number(process.env.ELO_K ?? 32);

  const [u1, u2] = await Promise.all([
    prisma.user.findFirst({ where: { username: { equals: p1, mode: "insensitive" } } }),
    prisma.user.findFirst({ where: { username: { equals: p2, mode: "insensitive" } } }),
  ]);
  if (!u1 || !u2) {
    const missing = [!u1 ? p1 : null, !u2 ? p2 : null].filter(Boolean).join(", ");
    return bad(`unknown user(s): ${missing}`, 404);
  }

  // p1 is winner; p2 is loser
  const winnerUser = u1, loserUser = u2;
  const Ra = winnerUser.elo ?? 1200;
  const Rb = loserUser.elo ?? 1200;

  const r = updateElo(Ra, Rb, 1, K);
  const newA = r.newA, newB = r.newB;
  const dA = r.deltaA, dB = r.deltaB;

  // Ensure the raw delta table exists (no Prisma schema changes)
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS match_elo_delta (
      id          bigserial PRIMARY KEY,
      match_id    text NOT NULL,
      user_id     text NOT NULL,
      before_elo  int  NOT NULL,
      after_elo   int  NOT NULL,
      delta       int  NOT NULL,
      created_at  timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_match_elo_delta_match ON match_elo_delta(match_id);
    CREATE INDEX IF NOT EXISTS idx_match_elo_delta_user  ON match_elo_delta(user_id);
  `);

  // Try to settle an OPEN match for this channel/pair first (any order)
  const open = await prisma.match.findFirst({
    where: {
      channelId,
      state: "OPEN",
      OR: [
        { p1UserId: winnerUser.id, p2UserId: loserUser.id },
        { p1UserId: loserUser.id,  p2UserId: winnerUser.id },
      ],
    },
    orderBy: { openedAt: "desc" },
  });

  const tx = await prisma.$transaction(async (px) => {
    const match = open
      ? await px.match.update({
          where: { id: open.id },
          data: { state: "SETTLED", loserScore: ls, winnerUserId: winnerUser.id, settledAt: now },
        })
      : await px.match.create({
          data: {
            channelId,
            p1UserId: winnerUser.id,
            p2UserId: loserUser.id,
            state: "SETTLED",
            loserScore: ls,
            winnerUserId: winnerUser.id,
            openedBy,
            openedAt: now,
            settledAt: now,
          },
        });

    // Update users
    await px.user.update({
      where: { id: winnerUser.id },
      data: { elo: newA, wins: (winnerUser.wins ?? 0) + 1 },
    });
    await px.user.update({
      where: { id: loserUser.id },
      data: { elo: newB, losses: (loserUser.losses ?? 0) + 1 },
    });

    // Insert Elo deltas (parameterized, no injection)
    await px.$executeRaw`
      INSERT INTO match_elo_delta (match_id, user_id, before_elo, after_elo, delta, created_at)
      VALUES (${match.id}, ${winnerUser.id}, ${Ra}, ${newA}, ${dA}, ${now})
    `;
    await px.$executeRaw`
      INSERT INTO match_elo_delta (match_id, user_id, before_elo, after_elo, delta, created_at)
      VALUES (${match.id}, ${loserUser.id}, ${Rb}, ${newB}, ${dB}, ${now})
    `;

    return match;
  });

  return json({
    ok: true,
    recordedAt: now.toISOString(),
    matchId: tx.id,
    channelId,
    winner: winnerUser.username,
    loser: loserUser.username,
    loserScore: ls,
    elo: {
      [winnerUser.username]: { before: Ra, after: newA, delta: dA },
      [loserUser.username]:  { before: Rb, after: newB, delta: dB },
    },
  });
}
