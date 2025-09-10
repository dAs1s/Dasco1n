import tmi from "tmi.js";
import { ENV } from "./lib/env.js";
import { api } from "./lib/api.js";
import { hasEnoughDascoin } from "./lib/se.js";
import { logger } from "./lib/logger.js";

type Handler = (channel: string, user: tmi.ChatUserstate, args: string[], respond: (msg: string) => Promise<void>) => Promise<void>;

const PREFIX = "!";

function parseIntStrict(s: string): number | null {
  if (!/^[-+]?\d+$/.test(s)) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

async function safeCall<T>(fn: () => Promise<T>, respond: (m: string) => Promise<void>) {
  try {
    return await fn();
  } catch (err: any) {
    const msg = err?.response?.data?.error ?? err?.message ?? "Unknown error";
    await respond(`Error: ${msg}`);
    logger.error(String(err));
    return undefined;
  }
}

// Commands
const commands = new Map<string, Handler>();

commands.set("startbet", async (channel, user, args, respond) => {
  const [a, b] = args;
  if (!a || !b) return respond("Usage: !startBet <playerA> <playerB>");
  await safeCall(() => api.post("/api/matches/open", { p1: a, p2: b, channelId: ENV.CHANNEL_ID }), respond);
  await respond(`Bet started: ${a} vs ${b}. Use !bet <1|2> <loserScore 0-9> <amount>`);
});

commands.set("bet", async (channel, user, args, respond) => {
  const [c, l, amt] = args;
  const choice = parseIntStrict(c ?? ""); if (!(choice === 1 || choice === 2)) return respond("Usage: !bet <1|2> <loserScore 0-9> <amount>");
  const loserScore = parseIntStrict(l ?? ""); if (loserScore === null || loserScore < 0 || loserScore > 9) return respond("Loser score must be 0-9.");
  const amount = parseIntStrict(amt ?? ""); if (amount === null || amount <= 0) return respond("Amount must be a positive integer.");
  const username = (user["display-name"] || user.username || "").toString();
  if (!username) return respond("Unable to resolve your username.");
  if (!(await hasEnoughDascoin(username, amount))) return respond("You don't have enough DasCoin (SE precheck).");

  await safeCall(() => api.post("/api/bets/current/place",
      { username, choice, loserScore, amount },
      { headers: { "x-username": username } }),
    respond);

  await respond(`Bet accepted @${username}: on player ${choice}, loser score ${loserScore}, amount ${amount} DSC.`);
});

commands.set("refund", async (channel, user, _args, respond) => {
  const username = (user["display-name"] || user.username || "").toString();
  if (!username) return respond("Unable to resolve your username.");
  await safeCall(() => api.post("/api/bets/current/refund", { username }, { headers: { "x-username": username } }), respond);
  await respond(`@${username} your last bet has been refunded.`);
});

commands.set("lockbet", async (_ch, _user, _args, respond) => {
  await safeCall(() => api.post("/api/matches/current/lock", {}), respond);
  await respond("Bets are now locked.");
});

commands.set("recordresult", async (_ch, _user, args, respond) => {
  const [w, l] = args;
  const winner = parseIntStrict(w ?? ""); if (!(winner === 1 || winner === 2)) return respond("Usage: !recordResult <1|2> <loserScore 0-9>");
  const loserScore = parseIntStrict(l ?? ""); if (loserScore === null || loserScore < 0 || loserScore > 9) return respond("Loser score must be 0-9.");
  await safeCall(() => api.post("/api/matches/current/record", { winner, loserScore }), respond);
  await respond(`Result recorded: Winner ${winner}, Loser score ${loserScore}.`);
});

async function inc(which: 1|2) {
  const cur = await api.get("/api/matches/current");
  const m = cur.data?.match ?? {};
  const p1 = Number(m?.scoreP1 ?? 0) + (which === 1 ? 1 : 0);
  const p2 = Number(m?.scoreP2 ?? 0) + (which === 2 ? 1 : 0);
  await api.post("/api/matches/current/score", { p1Score: p1, p2Score: p2 });
}
commands.set("1", async (_c,_u,_a, respond) => { await safeCall(() => inc(1), respond); await respond("Incremented Player 1 score by 1."); });
commands.set("2", async (_c,_u,_a, respond) => { await safeCall(() => inc(2), respond); await respond("Incremented Player 2 score by 1."); });

commands.set("setscore", async (_ch, _user, args, respond) => {
  const [s1, s2] = args;
  const p1 = parseIntStrict(s1 ?? ""); const p2 = parseIntStrict(s2 ?? "");
  if (p1 === null || p2 === null) return respond("Usage: !setScore <p1> <p2>");
  await safeCall(() => api.post("/api/matches/current/score", { p1Score: p1, p2Score: p2 }), respond);
  await respond(`Set score to ${p1} : ${p2}`);
});

async function topText(url: string, title: string, key: "elo"|"balance") {
  const res = await api.get(url);
  const items = (res.data?.items ?? res.data ?? []) as Array<{ username: string; [k: string]: number }>;
  const text = items.slice(0, 10).map((u, idx) => `${idx + 1}. ${u.username} — ${key === "elo" ? "ELO " + u.elo : u.balance + (title.includes("DasCoin") ? " DSC" : " GPC")}`).join(" | ");
  return `Top 10 ${title}: ${text || "No data"}`;
}
commands.set("top10ladder", async (_c, _u, _a, respond) => {
  await safeCall(async () => respond(await topText("/api/leaderboards/elo", "Ladder", "elo")), respond);
});
commands.set("top10dascoin", async (_c, _u, _a, respond) => {
  await safeCall(async () => respond(await topText("/api/leaderboards/dsc", "DasCoin", "balance")), respond);
});
commands.set("top10glorpcoin", async (_c, _u, _a, respond) => {
  await safeCall(async () => respond(await topText("/api/leaderboards/gpc", "GlorpCoin", "balance")), respond);
});

// Bootstrap
const client = new tmi.Client({
  options: { debug: false },
  identity: { username: ENV.TWITCH_BOT_USERNAME, password: ENV.TWITCH_OAUTH_TOKEN },
  channels: ENV.TWITCH_CHANNELS,
});

client.on("message", async (channel, userstate, message, self) => {
  if (self) return;
  if (!message.startsWith(PREFIX)) return;
  const parts = message.slice(PREFIX.length).trim().split(/\s+/);
  const name = (parts.shift() || "").toLowerCase();
  const handler = commands.get(name);
  const respond = (msg: string) => client.say(channel, msg);
  if (!handler) return;
  await handler(channel, userstate, parts, respond);
});

client.on("connected", (_addr, _port) => {
  logger.info(`[READY] Twitch bot connected as ${ENV.TWITCH_BOT_USERNAME} -> ${ENV.TWITCH_CHANNELS.join(", ")}`);
});

client.connect().catch((e) => {
  logger.error("Failed to connect to Twitch IRC: " + e?.message);
});
