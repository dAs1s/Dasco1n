// bots/discord/commands/myStats.ts
import type { Command } from './index';

const myStats: Command = async ({ msg, helpers }) => {
  try {
    // Your GET /api/users/[username] supports discordId too (OR: username, twitchId, discordId, id)
    const data = await helpers.getJSON(`/api/users/${encodeURIComponent(msg.author.id)}`);
    await msg.reply(`**${data.username}** | ELO ${data.elo} | W:${data.wins} L:${data.losses}`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default myStats;
