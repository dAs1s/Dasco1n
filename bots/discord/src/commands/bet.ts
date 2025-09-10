import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/bet.ts
import type { Command } from './index';

const bet: Command = async ({ msg, args, helpers }) => {
  if (args.length < 3) return void msg.reply('Usage: `!bet <1|2> <loserScore> <amount>`');
  const [choiceStr, loserStr, amountStr] = args;
  const body = {
    choice: Number(choiceStr),
    loserScore: Number(loserStr),
    amount: Number(amountStr),
    user: msg.author.username,
    discordId: msg.author.id,
    channelId: 'discord',
  };
  try {
    const data = await postJSON('/api/bets', body);
    await msg.reply(`✅ Bet placed: ${data.summary ?? 'ok'}`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default bet;
