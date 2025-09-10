// bots/discord/commands/myMatchHistory.ts
import type { Command } from './index';

const myMatchHistory: Command = async ({ msg, helpers }) => {
  try {
    const id = msg.author.id;
    const data = await helpers.getJSON(`/api/matches/history?discordId=${encodeURIComponent(id)}`)
      .catch(() => helpers.getJSON(`/api/matches/history?user=${encodeURIComponent(msg.author.username)}`));

    const matches = (data.matches ?? []) as Array<any>;
    if (!matches.length) return void msg.reply('No matches found.');

    // Already sorted earliest→latest by API. Number them.
    const lines = matches.map((m, i) =>
      `${i + 1}. ${m.p1Name} vs ${m.p2Name} — ${m.winnerName} won ${m.winnerScore}-${m.loserScore}`
    );

    // Cap to avoid 2k char overflow
    const out = lines.join('\n');
    if (out.length <= 1900) return void msg.reply(out);

    let chunk = '';
    for (const line of lines) {
      if ((chunk + line + '\n').length > 1800) {
        await msg.reply(chunk);
        chunk = '';
      }
      chunk += line + '\n';
    }
    if (chunk) await msg.reply(chunk);
  } catch (e: any) {
    return void msg.reply(`❌ ${e?.message || 'internal error'}`);
  }
};

export default myMatchHistory;
