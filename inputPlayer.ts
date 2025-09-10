// bots/discord/commands/inputPlayer.ts
import type { Command } from './index';

const inputPlayer: Command = async ({ msg, args, helpers }) => {
  if (args.length < 1) return void msg.reply('Usage: `!inputPlayer <username>`');
  const username = args[0];
  try {
    const data = await helpers.postJSON('/api/users', { username });
    await msg.reply(`✅ Created user **${data.username ?? username}**`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default inputPlayer;
