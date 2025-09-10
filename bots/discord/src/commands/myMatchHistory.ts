import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/myMatchHistory.ts
import type { Command } from './index';

const myMatchHistory: Command = async ({ msg, helpers }) => {
  try {
    const data = await getJSON(`/api/matches/history?user=${encodeURIComponent(msg.author.id)}`);
    const items = data.items ?? data.matches ?? data ?? [];
    if (!items.length) return void msg.reply('No matches found.');
    const lines = items.slice(0, 20).map((m: any) => `• ${m.p1 ?? '?'} vs ${m.p2 ?? '?'} — ${m.score ?? (m.winner ?? '?')}`);
    await msg.reply(lines.join('\n'));
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default myMatchHistory;
