import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/inputTwitchName.ts
import type { Command } from './index';

const inputTwitchName: Command = async ({ msg, args, helpers }) => {
  const [username, twitchLogin] = args;
  if (!username || !twitchLogin) return void msg.reply('Usage: `!inputTwitchName <username> <twitchLogin>`');
  try {
    const data = await helpers.patchJSON('/api/users/link-twitch', { username, twitchLogin });
    await msg.reply(`✅ Linked Twitch for **${data.username ?? username}** → ${twitchLogin}`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default inputTwitchName;
