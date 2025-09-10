import type { Command } from "./index";
import * as path from "node:path";
import * as fs from "node:fs";

function apiBase(): string {
  const b = (process.env.API_BASE || process.env.API_BASE_URL || "http://127.0.0.1:3000").trim();
  return b.replace(/\/+$/, "");
}
async function fetchJson(url: string) {
  const res = await fetch(url, { headers: { accept: "application/json" } });
  if (!res.ok) return { ok: false, status: res.status, data: undefined };
  try { return { ok: true, status: res.status, data: await res.json() }; }
  catch { return { ok: true, status: res.status, data: undefined }; }
}
function readLinks(): { discordId: string; twitchLogin?: string; twitchId?: string; username?: string }[] {
  try {
    const file = path.join(process.cwd(), "data", "userlinks.json");
    if (!fs.existsSync(file)) return [];
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch { return []; }
}
function trimArray<T>(arr: T[] | undefined, max: number): T[] {
  if (!arr || !Array.isArray(arr)) return [];
  return arr.slice(0, Math.max(0, max));
}
function mentionFromDiscordId(id?: string) { return id ? `<@${id}>` : null; }

function formatProfile(p: {
  username: string;
  twitchId?: string | null;
  discordMention?: string | null;
  elo?: number | null;
  ladderRank?: number | null;
  wins?: number | null;
  losses?: number | null;
  matchHistory: Array<{
    winnerUsername?: string;
    winnerScore?: number;
    loserUsername?: string;
    loserScore?: number;
    eloChange?: number | null;
    recordedAt?: string | null;
  }>;
  wallet: Array<{ name?: string; symbol?: string; price?: number | null; logo?: string | null; balance?: number | null }>;
}) {
  const lines: string[] = [];
  lines.push(`**Stats for ${p.username}**`);
  if (p.discordMention) lines.push(`Discord: ${p.discordMention}`);
  if (p.twitchId) lines.push(`TwitchID: ${p.twitchId}`);
  lines.push(`ELO: ${p.elo ?? "—"}   Ladder Rank: ${p.ladderRank ?? "—"}`);
  lines.push(`Record: ${p.wins ?? 0}W-${p.losses ?? 0}L`);

  const matches = trimArray(p.matchHistory, 8);
  if (matches.length) {
    lines.push("");
    lines.push("**Recent Matches**");
    for (const m of matches) {
      const delta = (m.eloChange === 0 || m.eloChange) ? ` (${m.eloChange>0?"+":""}${m.eloChange})` : "";
      const when = m.recordedAt ? ` • ${m.recordedAt}` : "";
      lines.push(`• ${m.winnerUsername} ${m.winnerScore ?? ""} – ${m.loserUsername} ${m.loserScore ?? ""}${delta}${when}`);
    }
  }

  const coins = trimArray(p.wallet, 8);
  if (coins.length) {
    lines.push("");
    lines.push("**Wallet**");
    for (const c of coins) {
      const price = (c.price === 0 || c.price) ? ` @ ${c.price}` : "";
      const bal = (c.balance === 0 || c.balance) ? ` × ${c.balance}` : "";
      lines.push(`• ${c.name || c.symbol} (${c.symbol})${price}${bal}`);
    }
  }
  return lines.join("\n");
}

async function buildProfile(login: string) {
  const base = apiBase();
  // basic user
  const u = await fetchJson(`${base}/api/users/${encodeURIComponent(login)}`);
  const user = u.ok && u.data ? u.data : null;

  // ladder
  let ladderRank: number | null = null;
  const lad = await fetchJson(`${base}/api/ladder?limit=10000`);
  if (lad.ok && lad.data && Array.isArray(lad.data.items)) {
    let i = 0;
    for (const row of lad.data.items) {
      i++;
      if ((row?.username || row?.name) === login) { ladderRank = i; break; }
    }
  } else {
    const all = await fetchJson(`${base}/api/users?all=1`);
    if (all.ok && all.data && Array.isArray(all.data.items)) {
      const sorted = all.data.items.filter((r: any) => r.elo !== undefined && r.elo !== null)
        .sort((a: any, b: any) => (b.elo ?? 0) - (a.elo ?? 0));
      let i = 0;
      for (const row of sorted) { i++; if (row.username === login) { ladderRank = i; break; } }
    }
  }

  // matches
  const mh = await fetchJson(`${base}/api/matches?user=${encodeURIComponent(login)}&limit=100`);
  const matchHistory = (mh.ok && mh.data && Array.isArray(mh.data.items) ? mh.data.items : []).map((m: any) => ({
    winnerUsername: m?.winner,
    winnerScore: m?.winnerScore,
    loserUsername:  m?.loser,
    loserScore: m?.loserScore,
    eloChange: (m && (m.eloChange === 0 || m.eloChange)) ? m.eloChange : null,
    recordedAt: m?.playedAt || m?.recordedAt || null,
  }));

  // wallet (+ coin meta best-effort)
  const w = await fetchJson(`${base}/api/wallets?user=${encodeURIComponent(login)}`);
  const walletItems = (w.ok && w.data && Array.isArray(w.data.items) ? w.data.items : []);
  const wallet: any[] = [];
  for (const it of walletItems) {
    const sym = it?.symbol;
    let name = sym, price = null, logo = null;
    if (sym) {
      let meta = await fetchJson(`${base}/api/coins/${encodeURIComponent(sym)}`);
      if (!(meta.ok && meta.data)) meta = await fetchJson(`${base}/api/coins?symbol=${encodeURIComponent(sym)}`);
      const m = meta.data?.item || meta.data || {};
      if (m?.name) name = m.name;
      if (m?.price === 0 || m?.price) price = m.price;
      if (m?.logo) logo = m.logo;
    }
    wallet.push({ name, symbol: sym, price, logo, balance: it?.balance ?? null });
  }

  return {
    username: login,
    twitchId: user?.twitchId ?? user?.id ?? null,
    discordMention: null,
    elo: (user && (user.elo === 0 || user.elo)) ? user.elo : null,
    ladderRank,
    wins: user?.wins ?? null,
    losses: user?.losses ?? null,
    matchHistory,
    wallet,
  };
}

const stats: Command = async ({ msg, args }) => {
  const login = (args[0] || "").trim().toLowerCase();
  if (!login) {
    await msg.reply("Usage: `!stats <twitchLogin>`");
    return;
  }
  const links = readLinks();
  const link = links.find(l => (l.twitchLogin || "").toLowerCase() === login);
  const profile = await buildProfile(login);
  if (link?.discordId) profile.discordMention = `<@${link.discordId}>`;
  const out = formatProfile(profile);
  await msg.reply(out);
};

export default stats;