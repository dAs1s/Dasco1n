// bots/discord/commands/remove.ts
import type { Command } from './index';

const remove: Command = async ({ msg, args, helpers, isMod }) => {
  if (!isMod) return void msg.reply('⛔ Mods only.');
  if (args.length < 3) return void msg.reply('Usage: `!remove <p1> <p2> <loserScore>`');
  const [p1, p2, loserScoreStr] = args;
  try {
    await helpers.delJSON('/api/matches/record', { p1, p2, loserScore: Number(loserScoreStr) });
    await msg.reply(`🗑️ Removed: ${p1} vs ${p2} (${loserScoreStr})`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default remove;
