import type { Command } from "./index";
import * as fs from "node:fs";
import * as path from "node:path";

/**
 * Scan the commands folder and list the actual command names that are present.
 * - includes *.ts under src/commands
 * - excludes _disabled/ and files starting with "_" and any *.disabled
 * - name is lowercase of the basename (e.g. myStats.ts -> mystats)
 */
function listAvailableCommands(): string[] {
  const root = process.cwd();
  const cmdDir = path.join(root, "src", "commands");
  const out: string[] = [];

  function walk(dir: string) {
    let entries: fs.Dirent[];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      // skip disabled folder
      if (e.isDirectory()) {
        if (e.name.startsWith("_disabled")) continue;
        walk(path.join(dir, e.name));
        continue;
      }
      if (!e.isFile()) continue;

      const file = e.name;
      // only .ts files
      if (!file.endsWith(".ts")) continue;
      // ignore files like "discord.ts.disabled"
      if (file.endsWith(".ts.disabled")) continue;
      // ignore private/underscore files (e.g. _types.ts)
      if (file.startsWith("_")) continue;

      const base = path.basename(file, ".ts"); // e.g. myStats
      // index.ts here is the registry file, not a command
      if (base.toLowerCase() === "index") continue;

      out.push(base.toLowerCase());
    }
  }

  walk(cmdDir);

  // de-dupe + sort
  const seen = new Set<string>();
  const uniq = out.filter(n => {
    if (seen.has(n)) return false;
    seen.add(n);
    return true;
  }).sort((a, b) => a.localeCompare(b));

  return uniq;
}

// Optional friendly descriptions for known commands (fallback is name only)
const DESCR: Record<string, string> = {
  bet: "Place a bet",
  dascoin: "Show your StreamElements coin balance",
  help: "Show this help",
  inputdiscordname: "Link a Discord name to your user",
  inputplayer: "Link a player name",
  inputtwitchname: "Link a Twitch name",
  inputuser: "Link username, Twitch login, and Discord mention",
  ladder: "Show the ladder in ELO order",
  listall: "List all users",
  matchhistory: "Show match history for a user",
  mymatchhistory: "Show your match history",
  mystats: "Show your stats",
  mywallet: "Show your wallet",
  record: "Record a match result",
  remove: "Remove a user link",
  search: "Search users",
  stats: "Show stats for a user"
};

function chunkAndSend(text: string, send: (t: string)=>Promise<void>): Promise<void> {
  const MAX = 1900; // be safe under 2000
  let buf = "";
  async function flush() {
    if (buf.trim().length) {
      await send(buf);
      buf = "";
    }
  }
  return (async () => {
    for (const ln of text.split("\n")) {
      if ((buf + ln + "\n").length > MAX) await flush();
      buf += ln + "\n";
    }
    await flush();
  })();
}

const help: Command = async ({ msg }) => {
  const cmds = listAvailableCommands();

  if (!cmds.length) {
    await msg.reply("ℹ️ No commands found.");
    return;
  }

  // Build a tidy help message
  const lines: string[] = [];
  lines.push("**Available Commands**");
  lines.push("Use: `!<command> [args]`");
  lines.push("");

  for (const c of cmds) {
    const d = DESCR[c] ? ` — ${DESCR[c]}` : "";
    lines.push(`\`${c}\`${d}`);
  }

  const body = lines.join("\n");
  await chunkAndSend(body, async (t) => { await msg.reply(t); });
};

export default help;