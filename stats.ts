// bots/discord/commands/stats.ts
import type { Command } from './index';

const stats: Command = async ({ msg, args, helpers }) => {
  const who = args[0] ?? msg.author.username;
  try {
    const data = await helpers.getJSON(`/api/users/${encodeURIComponent(who)}`);
    await msg.reply(`**${data.username}** | ELO ${data.elo} | W:${data.wins} L:${data.losses}`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default stats;
