import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/inputPlayer.ts
import type { Command } from './index';

const inputPlayer: Command = async ({ msg, args, helpers }) => {
  const [username] = args;
  if (!username) return void msg.reply('Usage: `!inputPlayer <username>`');
  try {
    const data = await postJSON('/api/users', { username });
    await msg.reply(`✅ Player created/updated: **${data.username ?? username}**`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default inputPlayer;
