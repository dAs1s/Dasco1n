// bots/discord/commands/inputDiscordName.ts
import type { Command } from './index';
import { parseMentionOrId } from '../util/parsing';

const inputDiscordName: Command = async ({ msg, args, helpers }) => {
  if (args.length < 2) return void msg.reply('Usage: `!inputDiscordName <username> <@mention|id>`');
  const [username, target] = args;
  const discordId = parseMentionOrId(target);
  if (!discordId) return void msg.reply('Provide a valid @mention or numeric Discord ID.');
  try {
    // PATCH /api/users/:username with { discordId }
    await helpers.patchJSON(`/api/users/${encodeURIComponent(username)}`, { discordId });
    await msg.reply(`🔗 Linked **${username}** ⇄ <@${discordId}>`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default inputDiscordName;
