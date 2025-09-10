import type { Command } from "./index";
import * as fs from "node:fs";
import * as path from "node:path";

type Link = { discordId: string; twitchLogin?: string; twitchId?: string };

function ensureLinksFile(file: string) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) fs.writeFileSync(file, "[]");
}
function loadLinks(file: string): Link[] {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch { return []; }
}
function pickDiscordId(input: string | undefined, authorId: string): string {
  if (!input) return authorId;
  const m = input.match(/^<@!?(\d+)>$/);
  if (m) return m[1];
  if (/^\d+$/.test(input)) return input;
  return authorId;
}

function b64urlToJson(b64: string): any | null {
  try {
    const s = b64.replace(/-/g, "+").replace(/_/g, "/");
    const pad = s.length % 4 === 2 ? "==" : s.length % 4 === 3 ? "=" : "";
    const json = Buffer.from(s + pad, "base64").toString("utf8");
    return JSON.parse(json);
  } catch { return null; }
}
function decodeJwtPayload(jwt: string | undefined): any | null {
  if (!jwt) return null;
  const parts = jwt.split(".");
  if (parts.length !== 3) return null;
  return b64urlToJson(parts[1]);
}

type TryResult = {
  ok: boolean;
  status: number;
  url: string;
  points?: number;
  bodyText?: string;
};

async function tryPoints(channel: string, user: string, jwt?: string): Promise<TryResult> {
  const url = `https://api.streamelements.com/kappa/v2/points/${encodeURIComponent(channel)}/${encodeURIComponent(user)}`;
  const headers: Record<string,string> = { accept: "application/json" };
  if (jwt) headers.authorization = `Bearer ${jwt}`;
  const res = await fetch(url, { headers });
  let bodyText = "";
  try { bodyText = await res.text(); } catch {}

  let points: number | undefined = undefined;
  try {
    const data: any = bodyText ? JSON.parse(bodyText) : undefined;
    if (data) {
      if (typeof data.points === "number") points = data.points;
      else if (typeof data.total === "number") points = data.total;
      else if (typeof data.current === "number") points = data.current;
      else if (data.point && typeof data.point.current === "number") points = data.point.current;
    }
  } catch {
    // ignore JSON parse errors
  }

  return { ok: res.ok, status: res.status, url, points, bodyText };
}

const dascoin: Command = async ({ msg, args }) => {
  const DEBUG = (process.env.DEBUG || "").toLowerCase().includes("dascoin");

  // ENV: allow explicit channel login (NEW) in addition to existing ID/uuid/provider_id
  const envChanId     = (process.env.SE_CHANNEL_ID || process.env.STREAMELEMENTS_CHANNEL || "").trim();
  const envChanLogin  = (process.env.SE_CHANNEL_LOGIN || process.env.STREAMELEMENTS_CHANNEL_LOGIN || "").trim(); // <- try login
  const jwt           = (process.env.SE_JWT || process.env.STREAMELEMENTS_JWT || "").trim();

  const payload = decodeJwtPayload(jwt || undefined);
  const fromJwtChannelId  = payload?.channel_id ? String(payload.channel_id).trim() : "";
  const fromJwtProviderId = payload?.provider_id ? String(payload.provider_id).trim() : "";
const fromJwtChannelHex  = payload && typeof (payload as any).channel === "string" ? String((payload as any).channel).trim() : "";

  // try login first (if present), then your existing env value, then JWT-derived ids
  const channelCandidates: string[] = [];
  if (fromJwtChannelHex) channelCandidates.push(fromJwtChannelHex);
if (envChanLogin) channelCandidates.push(envChanLogin);
  if (envChanId)    channelCandidates.push(envChanId);
  if (fromJwtChannelId)  channelCandidates.push(fromJwtChannelId);
  if (fromJwtProviderId) channelCandidates.push(fromJwtProviderId);

  const seen = new Set<string>();
  const channels = channelCandidates.filter(c => {
    const key = (c || "").toLowerCase();
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  if (channels.length === 0) {
    await msg.reply("⚠️ Set **SE_CHANNEL_LOGIN** (your Twitch channel login, e.g. `dasm1ns`) or **SE_CHANNEL_ID** in ROOT `.env`. Keep **SE_JWT** valid if your channel requires it.");
    return;
  }

  // Load link for target (default: author)
  const file = path.join(process.cwd(), "data", "userlinks.json");
  ensureLinksFile(file);
  const links = loadLinks(file);
  const targetId = pickDiscordId(args[0], msg.author.id);
  const link = links.find(l => l.discordId === targetId);

  if (!link) {
    await msg.reply("❌ No Twitch link found. Use `!inputuser <tLogin> <tId|-> <@mention>` first.");
    return;
  }

  // try the login first, then id
  const userCandidates: string[] = [];
  if (link.twitchLogin) userCandidates.push(String(link.twitchLogin).toLowerCase());
  if (link.twitchId)    userCandidates.push(String(link.twitchId));

  if (userCandidates.length === 0) {
    await msg.reply("❌ Stored link has no twitch login/id. Re-run `!inputuser`.");
    return;
  }

  if (DEBUG) {
    console.log("[dascoin] envChanId=%s envChanLogin=%s jwt=%s", envChanId || "<empty>", envChanLogin || "<empty>", jwt ? "present" : "absent");
    console.log("[dascoin] jwt.channel_id=%s jwt.provider_id=%s", fromJwtChannelId || "<empty>", fromJwtProviderId || "<empty>");
    console.log("[dascoin] channels=%j", channels);
    console.log("[dascoin] userCandidates=%j for discordId=%s", userCandidates, targetId);
  }

  const attempts: { channel: string; user: string; status: number; url: string; snippet?: string }[] = [];
  for (const ch of channels) {
    for (const u of userCandidates) {
      try {
        const r = await tryPoints(ch, u, jwt || undefined);
        const snippet = r.bodyText ? r.bodyText.slice(0, 160) : "";
        attempts.push({ channel: ch, user: u, status: r.status, url: r.url, snippet });

        if (DEBUG) console.log("[dascoin] try %s → HTTP %s points=%s body=%s", r.url, r.status, r.points ?? "<none>", snippet || "<empty>");

        if (r.ok && typeof r.points === "number") {
          const who = targetId === msg.author.id ? "You" : `<@${targetId}>`;
          await msg.reply(`💰 ${who} have **${r.points.toLocaleString("en-US")}** Dascoin.`);
          return;
        }
      } catch (e: any) {
        if (DEBUG) console.log("[dascoin] request error for %s/%s: %s", ch, u, e?.message || String(e));
      }
    }
  }

  const who = targetId === msg.author.id ? "You" : `<@${targetId}>`;
  let summary = attempts.map(a => `${a.channel}/${a.user} → ${a.status}`).join(", ");
  if (!summary) summary = "(no attempts)";
  await msg.reply(`❌ Could not find points for ${who}. Tried: ${summary}. Set **SE_CHANNEL_LOGIN** to your Twitch login (e.g. dasm1ns) or keep **SE_JWT** valid. (Enable DEBUG=dascoin for response bodies.)`);
};

export default dascoin;

