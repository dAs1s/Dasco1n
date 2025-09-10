// bots/discord/commands/inputUser.ts
import type { Command } from './index';

function parseDiscordId(raw: string): string | null {
  if (!raw) return null;
  const s = raw.trim();
  // <@123>, <@!123>, or plain 18+ digit ID
  const mention = s.match(/^<@!?(\d+)>$/);
  if (mention) return mention[1];
  if (/^\d{15,22}$/.test(s)) return s;
  return null;
}

const inputUser: Command = async ({ msg, args, helpers }) => {
  if (args.length < 3) {
    return void msg.reply('Usage: `!inputUser <username> <twitchId> <@discord|id>`');
  }

  const [usernameRaw, twitchIdRaw, discordRaw] = args;
  const username = (usernameRaw ?? '').trim();
  const twitchId = (twitchIdRaw ?? '').trim();
  const discordId = parseDiscordId(discordRaw);

  if (!username) return void msg.reply('username is required.');
  if (!twitchId) return void msg.reply('twitchId is required.');
  if (!discordId) return void msg.reply('discord tag/id is invalid. Use `@mention` or a numeric ID.');

  try {
    // 1) Create the user (409 means it already exists — that’s fine)
    try {
      await helpers.postJSON('/api/users', { username });
    } catch (e: any) {
      const m = String(e?.message || '');
      if (!(m.includes('409') || /already exists/i.test(m))) throw e;
    }

    // 2) Patch both twitchId and discordId in one shot
    await helpers.patchJSON(`/api/users/${encodeURIComponent(username)}`, {
      twitchId,
      discordId,
    });

    await msg.reply(`✅ Saved **${username}** (twitchId: ${twitchId}, discordId: ${discordId})`);
  } catch (e: any) {
    await msg.reply(`❌ ${e?.message ?? 'internal error'}`);
  }
};

export default inputUser;
