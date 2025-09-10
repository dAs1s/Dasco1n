import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/search.ts
import type { Command } from './index';

const search: Command = async ({ msg, args, helpers }) => {
  const q = args.join(' ').trim();
  if (!q) return void msg.reply('Usage: `!search <query>`');
  try {
    const data = await getJSON(`/api/search?q=${encodeURIComponent(q)}`);
    const items = data.items ?? data.results ?? data ?? [];
    if (!items.length) return void msg.reply('No results.');
    const lines = items.slice(0, 20).map((it: any) => `• ${it.type ?? ''} ${it.username ?? it.name ?? it.id ?? ''}`);
    await msg.reply(lines.join('\n'));
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default search;
