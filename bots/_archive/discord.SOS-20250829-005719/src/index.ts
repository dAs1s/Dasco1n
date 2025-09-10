import "./lib/env.js";
import { Client, GatewayIntentBits, Partials, Events, type Message } from "discord.js";
import { registerSlashDefinitions } from "./deploy-commands.js";
import { logger } from "./lib/logger.js";

import * as startBet from "./commands/startBet.js";
import * as bet from "./commands/bet.js";
import * as refund from "./commands/refund.js";
import * as lockBet from "./commands/lockBet.js";
import * as recordResult from "./commands/recordResult.js";
import * as plus1 from "./commands/plus1.js";
import * as plus2 from "./commands/plus2.js";
import * as setScore from "./commands/setScore.js";
import * as top10Ladder from "./commands/top10Ladder.js";
import * as top10Dascoin from "./commands/top10Dascoin.js";
import * as top10Glorpcoin from "./commands/top10Glorpcoin.js";

const PREFIX = process.env.DISCORD_PREFIX ?? "!";

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent, // REQUIRED for "!" commands
  ],
  partials: [Partials.Channel],
});

// Command registry (both slash + prefix)
const commands = new Map<string, any>([
  ["startbet", startBet],
  ["bet", bet],
  ["refund", refund],
  ["lockbet", lockBet],
  ["recordresult", recordResult],
  ["plus1", plus1],
  ["plus2", plus2],
  ["setscore", setScore],
  ["top10ladder", top10Ladder],
  ["top10dascoin", top10Dascoin],
  ["top10glorpcoin", top10Glorpcoin],
  // aliases for numeric !1 / !2
  ["1", plus1],
  ["2", plus2],
]);

client.once(Events.ClientReady, () => {
  logger.info(`[READY] Logged in as ${client.user?.tag}`);
});

// Slash support (kept, but your focus is the "!" flow)
client.on(Events.InteractionCreate, async (i) => {
  if (!i.isChatInputCommand()) return;
  const name = i.commandName.toLowerCase();
  const mod = commands.get(name);
  if (!mod?.runSlash) return i.reply({ content: "Unknown command.", ephemeral: true });
  try {
    await mod.runSlash(i);
  } catch (err: any) {
    const msg = (err?.response?.data?.error ?? err?.message ?? "Unknown error").toString();
    if (i.deferred || i.replied) await i.followUp({ content: `Error: ${msg}`, ephemeral: true });
    else await i.reply({ content: `Error: ${msg}`, ephemeral: true });
  }
});

// Legacy "!" commands
client.on(Events.MessageCreate, async (msg: Message) => {
  try {
    if (!msg.guildId) return;    // ignore DMs
    if (msg.author.bot) return;  // ignore bots

    const content = msg.content?.trim() ?? "";
    if (!content.startsWith(PREFIX)) return;

    const without = content.slice(PREFIX.length).trim();
    const [rawCmd, ...args] = without.split(/\s+/);
    const name = rawCmd.toLowerCase();
    const mod = commands.get(name);
    if (!mod?.runPrefix) return;

    await mod.runPrefix(msg, args);
  } catch (err) {
    logger.error(`[MSG ERR] ${String(err)}`);
    try { await msg.reply("Error processing command."); } catch {}
  }
});

(async () => {
  try {
    await registerSlashDefinitions().catch((e) => logger.warn(`[WARN] Slash reg failed: ${e}`));
  } catch {}
  await client.login(process.env.DISCORD_TOKEN);
})();
