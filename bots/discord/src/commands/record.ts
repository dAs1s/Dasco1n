import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/record.ts
import type { Command } from './index';

const record: Command = async ({ msg, args, helpers, isMod }) => {
  if (!isMod) return void msg.reply('⛔ Mods only.');
  if (args.length < 3) return void msg.reply('Usage: `!record <p1> <p2> <loserScore>`');
  const [p1, p2, loserScoreStr] = args;
  try {
    await postJSON('/api/matches/record', {
      p1, p2, loserScore: Number(loserScoreStr),
      openedBy: `discord:${msg.author.id}`,
      channelId: 'discord',
    });
    await msg.reply(`✅ Recorded: ${p1} vs ${p2} (loser ${loserScoreStr})`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default record;
