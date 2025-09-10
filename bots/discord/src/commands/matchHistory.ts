import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/matchHistory.ts
import type { Command } from './index';

const matchHistory: Command = async ({ msg, args, helpers }) => {
  const who = args[0];
  if (!who) return void msg.reply('Usage: `!matchHistory <username>`');
  try {
    const data = await getJSON(`/api/matches/history?user=${encodeURIComponent(who)}`);
    const items = data.items ?? data.matches ?? data ?? [];
    if (!items.length) return void msg.reply('No matches found.');
    const lines = items.slice(0, 20).map((m: any) => `• ${m.p1 ?? '?'} vs ${m.p2 ?? '?'} — ${m.score ?? (m.winner ?? '?')}`);
    await msg.reply(lines.join('\n'));
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default matchHistory;
