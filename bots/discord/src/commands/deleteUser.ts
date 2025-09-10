import type { Command } from "./index";
import * as fs from "node:fs";
import * as path from "node:path";

type Link = { discordId: string; twitchLogin?: string; twitchId?: string; username?: string };

function ensureFile(file: string) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) fs.writeFileSync(file, "[]", "utf8");
}

const deleteUser: Command = async ({ msg, args }) => {
  const DEBUG = (process.env.DEBUG || "").toLowerCase().includes("deleteuser");
  const target = (args[0] || "").trim();
  if (!target) {
    await msg.reply("Usage: `!deleteuser <username>`");
    return;
  }

  const file = path.join(process.cwd(), "data", "userlinks.json");
  ensureFile(file);

  let arr: Link[] = [];
  try { arr = JSON.parse(fs.readFileSync(file, "utf8")); } catch {}
  const before = arr.length;

  const targetLc = target.toLowerCase();

  // Only remove entries whose 'username' matches target (case-insensitive).
  const kept = arr.filter(u => {
    const unameLc = (u.username || "").toLowerCase();
    const match = !!unameLc && unameLc === targetLc;
    if (DEBUG && match) console.log("[deleteuser] removing", u);
    return !match;
  });

  const removed = before - kept.length;
  if (removed > 0) {
    fs.writeFileSync(file, JSON.stringify(kept, null, 2), "utf8");
    await msg.reply(`🗑️ Removed **${removed}** user(s) with username \`${target}\` from the database.`);
  } else {
    await msg.reply(`❌ No user with username \`${target}\` found.`);
  }
};

export default deleteUser;