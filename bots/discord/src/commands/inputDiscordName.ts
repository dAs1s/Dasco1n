import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/inputDiscordName.ts
import type { Command } from './index';
import { parseMentionOrId } from '../util/parsing';

const inputDiscordName: Command = async ({ msg, args, helpers }) => {
  const [username, mention] = args;
  if (!username || !mention) return void msg.reply('Usage: `!inputDiscordName <username> <@mention|id>`');
  const discordId = parseMentionOrId(mention);
  if (!discordId) return void msg.reply('Please provide a valid @mention or numeric ID.');
  try {
    const data = await helpers.patchJSON('/api/users/link-discord', { username, discordId });
    await msg.reply(`✅ Linked Discord for **${data.username ?? username}** → <@${discordId}>`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default inputDiscordName;
