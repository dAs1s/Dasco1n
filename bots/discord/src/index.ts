import "./env";
import axios from "axios";
import { Client, GatewayIntentBits, Events } from "discord.js";
import { loadCommands } from "./commands";

const PREFIX = process.env.PREFIX ?? "!";
const API_BASE = process.env.API_BASE ?? "";

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
});

const commands = await loadCommands();

// v14-safe and v15-friendly
client.once(Events.ClientReady, async (client) => {
  console.log("✅ Discord bot ready as %s", client.user?.tag ?? "(unknown)");
  console.log("🔧 PREFIX=%s  API_BASE=%s", PREFIX, API_BASE || "(empty)");

  const names = Array.from(new Set(commands.keys())).sort();
  console.log("🧩 Commands: %s", names.length ? names.join(", ") : "(none)");

  // Optional: ping API so you see a clear message if it’s down/missing
  if (API_BASE) {
    try {
      const url = API_BASE.replace(/\/+$/, "") + "/health";
      await axios.get(url, { timeout: 3000 }).catch(async (e) => {
        // if /health 404s, try root as a fallback signal
        try { await axios.head(API_BASE, { timeout: 3000 }); } catch {}
        throw e;
      });
      console.log("🌐 API preflight OK");
    } catch (e: any) {
      console.warn("🌐 API preflight failed:", e?.message ?? e);
    }
  } else {
    console.warn("🌐 API_BASE is empty; commands that call your backend will fail.");
  }
});

client.on("messageCreate", async (msg) => {
  if (msg.author.bot) return;
  if (!msg.content.startsWith(PREFIX)) return;

  const without = msg.content.slice(PREFIX.length).trim();
  const [rawCmd, ...args] = without.split(/\s+/);
  const cmd = rawCmd.toLowerCase();

  const handler = commands.get(cmd);
  if (!handler) return;

  try {
    await handler({ msg, args, prefix: PREFIX });
  } catch (e) {
    console.error("Command %s failed:", cmd, e);
    try { await msg.reply("❌ Command error."); } catch {}
  }
});

const token = process.env.DISCORD_TOKEN;
if (!token || typeof token !== "string" || token.trim() === "") {
  console.error("❌ DISCORD_TOKEN is missing or invalid. Put it in C:\\Dasco1n\\.env");
  process.exit(1);
}

await client.login(token);
