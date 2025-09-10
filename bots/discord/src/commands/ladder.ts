import type { Command } from "./index";
import * as fs from "node:fs";
import * as path from "node:path";

type Link = { discordId: string; username?: string; twitchLogin?: string; twitchId?: string };
type Stat = { username?: string; twitchLogin?: string; discordId?: string; elo?: number; wins?: number; losses?: number };

function readJson(file: string): any | null {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch { return null; }
}
function ensureArray(x: any): any[] {
  if (!x) return [];
  return Array.isArray(x) ? x : [x];
}
function loadLinks(file: string): Link[] {
  const arr = readJson(file);
  const a = ensureArray(arr);
  return a.filter(Boolean).map((v: any) => ({
    discordId: String(v.discordId || v.discord || v.id || ""),
    username:  (v.username || v.name || v.user || "").toString().trim() || undefined,
    twitchLogin: (v.twitchLogin || v.twitch || v.twitchName || "").toString().trim() || undefined,
    twitchId: (v.twitchId || v.twitchID || v.tid || "").toString().trim() || undefined,
  })).filter(x => x.discordId);
}
function loadStatsFrom(file: string): Stat[] {
  const body = readJson(file);
  if (!body) return [];
  const arr = ensureArray(body);
  return arr.map((v: any) => {
    // try several common field names
    const elo =
      (typeof v.elo === "number" && v.elo) ||
      (typeof v.rating === "number" && v.rating) ||
      (typeof v.ELO === "number" && v.ELO);
    const wins =
      (typeof v.wins === "number" && v.wins) ||
      (typeof v.win === "number" && v.win) ||
      (typeof v.W === "number" && v.W) || 0;
    const losses =
      (typeof v.losses === "number" && v.losses) ||
      (typeof v.loss === "number" && v.loss) ||
      (typeof v.L === "number" && v.L) || 0;

    const username =
      (v.username || v.name || v.user || "").toString().trim() || undefined;
    const twitchLogin =
      (v.twitchLogin || v.twitch || v.twitchName || "").toString().trim() || undefined;
    const discordId =
      (v.discordId || v.discord || v.id || "").toString().trim() || undefined;

    const out: Stat = {};
    if (typeof elo === "number") out.elo = elo;
    out.wins = Number.isFinite(wins) ? wins : 0;
    out.losses = Number.isFinite(losses) ? losses : 0;
    if (username) out.username = username;
    if (twitchLogin) out.twitchLogin = twitchLogin;
    if (discordId) out.discordId = discordId;
    return out;
  }).filter(Boolean);
}

function findStats(dataDir: string): Stat[] {
  const candidates = [
    "stats.json",
    "players.json",
    "users.json",
    "profiles.json",
    "elo.json"
  ].map(f => path.join(dataDir, f));
  for (const f of candidates) {
    if (fs.existsSync(f)) {
      const arr = loadStatsFrom(f);
      if (arr.length) return arr;
    }
  }
  return [];
}

type Row = {
  key: string;                 // stable key for de-dupe/sort: prefer username -> twitchLogin -> discordId
  username?: string;
  twitchLogin?: string;
  discordId?: string;
  elo: number;
  wins: number;
  losses: number;
};

function buildRows(links: Link[], stats: Stat[]): Row[] {
  // index stats by known identifiers
  const byUser: Record<string, Stat> = {};
  const byLogin: Record<string, Stat> = {};
  const byDiscord: Record<string, Stat> = {};

  for (const s of stats) {
    const u = (s.username || "").toLowerCase();
    const l = (s.twitchLogin || "").toLowerCase();
    const d = (s.discordId || "");
    if (u) byUser[u] = s;
    if (l) byLogin[l] = s;
    if (d) byDiscord[d] = s;
  }

  const rows: Row[] = [];

  // union of links + any lone stats (in case some users don’t have links)
  const seen = new Set<string>();

  function pushRow(username?: string, twitchLogin?: string, discordId?: string, stat?: Stat) {
    const elo = (stat && typeof stat.elo === "number") ? stat.elo : 1000;
    const wins = (stat && typeof stat.wins === "number") ? stat.wins : 0;
    const losses = (stat && typeof stat.losses === "number") ? stat.losses : 0;
    // key preference: username > twitchLogin > discordId
    const key = (username || twitchLogin || discordId || "").toLowerCase();
    if (!key || seen.has(key)) return;
    seen.add(key);
    rows.push({ key, username, twitchLogin, discordId, elo, wins, losses });
  }

  // from links
  for (const l of links) {
    const u = (l.username || "").toLowerCase();
    const t = (l.twitchLogin || "").toLowerCase();
    const d = l.discordId;

    let stat: Stat | undefined = undefined;
    if (u && byUser[u]) stat = byUser[u];
    else if (t && byLogin[t]) stat = byLogin[t];
    else if (d && byDiscord[d]) stat = byDiscord[d];

    pushRow(l.username, l.twitchLogin, l.discordId, stat);
  }

  // add any remaining stats-only players not in links
  for (const s of stats) {
    const u = (s.username || "").toLowerCase();
    const t = (s.twitchLogin || "").toLowerCase();
    const d = (s.discordId || "");
    const key = (u || t || d || "").toLowerCase();
    if (!key || seen.has(key)) continue;
    pushRow(s.username, s.twitchLogin, s.discordId, s);
  }

  return rows;
}

function displayName(r: Row): string {
  // Prefer username, then twitchLogin, then Discord mention
  if (r.username) return r.username;
  if (r.twitchLogin) return r.twitchLogin;
  if (r.discordId) return `<@${r.discordId}>`;
  return "<unknown>";
}

function chunkAndSend(lines: string[], send: (t: string)=>Promise<void>): Promise<void> {
  // Discord hard cap 2000 chars; keep margin
  const MAX = 1900;
  let buf = "";
  async function flush() {
    if (buf.trim().length) {
      await send(buf);
      buf = "";
    }
  }
  return (async () => {
    for (const ln of lines) {
      if ((buf + ln + "\n").length > MAX) await flush();
      buf += ln + "\n";
    }
    await flush();
  })();
}

const ladder: Command = async ({ msg /*, args*/ }) => {
  const DEBUG = (process.env.DEBUG || "").toLowerCase().includes("ladder");

  const dataDir = path.join(process.cwd(), "data");
  const linksPath = path.join(dataDir, "userlinks.json");

  if (!fs.existsSync(linksPath)) {
    await msg.reply("❌ Missing `data/userlinks.json`.");
    return;
  }

  const links = loadLinks(linksPath);
  const stats = findStats(dataDir);

  if (DEBUG) {
    console.log("[ladder] links=%d stats=%d", links.length, stats.length);
  }

  const rows = buildRows(links, stats);

  if (rows.length === 0) {
    await msg.reply("ℹ️ No users found to list.");
    return;
  }

  // Sort: ELO desc, then name asc (case-insensitive)
  rows.sort((a, b) => {
    if (b.elo !== a.elo) return b.elo - a.elo;
    const an = displayName(a).toLowerCase();
    const bn = displayName(b).toLowerCase();
    return an.localeCompare(bn);
  });

  // Build output lines
  const lines: string[] = [];
  lines.push("**🏆 Ladder**");
  let rank = 1;
  for (const r of rows) {
    const name = displayName(r);
    lines.push(`${rank}. ${name} — ELO ${Math.round(r.elo)} (W-${r.wins}, L-${r.losses})`);
    rank++;
  }

  if (DEBUG) console.log("[ladder] prepared %d lines", lines.length);

  // Send in chunks if needed
  await chunkAndSend(lines, async (t) => { await msg.reply(t); });
};

export default ladder;