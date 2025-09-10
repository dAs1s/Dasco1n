// bots/discord/commands/search.ts
import type { Command } from './index';

const search: Command = async ({ msg, args, helpers }) => {
  if (!args[0]) return void msg.reply('Usage: `!search <query>`');
  try {
    const data = await helpers.getJSON(`/api/users/search?query=${encodeURIComponent(args.join(' '))}`);
    const rows = (data.results ?? []).map((u: any, i: number) =>
      `${i + 1}. ${u.username} (tw:${u.twitchId ?? '-'}, dc:${u.discordId ? 'linked' : '-'})`);
    await msg.reply(rows.length ? rows.join('\n') : 'No results.');
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default search;
