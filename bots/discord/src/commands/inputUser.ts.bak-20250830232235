import type { Command } from "./index";
import * as fs from "node:fs";
import * as path from "node:path";

type Link = { discordId: string; twitchLogin: string; username: string };

function ensure(file: string) {
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) fs.writeFileSync(file, "[]");
}
function parseMention(s: string): string | null {
  const m = s?.trim().match(/^<@!?(\d+)>$/);
  return m ? m[1] : null;
}

const inputuser: Command = async ({ msg, args }) => {
  // EXACT spec: !inputuser <username> <twitchLogin> <@mention|discordId>
  if (!args || args.length !== 3) {
    await msg.reply("Usage: `!inputuser <username> <twitchLogin> <@mention|discordId>`");
    return;
  }

  const username = String(args[0]).trim();
  const twitchLogin = String(args[1]).trim().toLowerCase();
  const who = String(args[2]).trim();

  let discordId = parseMention(who);
  if (!discordId && /^\d+$/.test(who)) discordId = who;

  if (!username || !twitchLogin || !discordId) {
    await msg.reply("❌ Invalid args. Usage: `!inputuser <username> <twitchLogin> <@mention|discordId>`");
    return;
  }

  const file = path.join(process.cwd(), "data", "userlinks.json");
  ensure(file);
  let links: Link[] = [];
  try { links = JSON.parse(fs.readFileSync(file, "utf8")); } catch { links = []; }

  const idx = links.findIndex(l => l.discordId === discordId);
  const newLink: Link = { discordId, twitchLogin, username };

  if (idx >= 0) { links[idx] = newLink; } else { links.push(newLink); }
  fs.writeFileSync(file, JSON.stringify(links, null, 2));

  await msg.reply(`✅ Linked <@${discordId}> ⇒ **${username}** / twitch **${twitchLogin}**.`);
};

export default inputuser;