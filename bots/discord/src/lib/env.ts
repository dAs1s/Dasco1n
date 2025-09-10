import path from "node:path";
import fs from "node:fs";
import dotenv from "dotenv";

// Try the repo root first, then fallbacks
const cwd = process.cwd();
const candidates = [
  path.resolve(cwd, "..", "..", ".env"),
  path.resolve(cwd, "..", ".env"),
  path.resolve(cwd, ".env"),
  process.env.DOTENV_CONFIG_PATH ?? ""
].filter(Boolean);

for (const p of candidates) {
  if (fs.existsSync(p)) { dotenv.config({ path: p }); break; }
}

// Normalize token (trim quotes & remove any "Bot " prefix)
const raw = (process.env.DISCORD_BOT_TOKEN ?? process.env.DISCORD_TOKEN ?? "").trim().replace(/^Bot\s+/i, "");
if (!raw || raw.split(".").length !== 3) {
  throw new Error("DISCORD_BOT_TOKEN missing/invalid. Put the 3-part token in C:\\Dasco1n\\.env as DISCORD_BOT_TOKEN=...");
}
process.env.DISCORD_BOT_TOKEN = raw;  // reassign normalized for consumers
