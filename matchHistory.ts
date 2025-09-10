// bots/discord/commands/matchHistory.ts
import type { Command } from './index';

function guessName(m: any, keyBase: 'p1' | 'p2' | 'winner'): string {
  // prefer denormalized names from the API
  return (
    m[`${keyBase}Name`] ||
    m[keyBase]?.username ||
    m[`${keyBase}Username`] ||
    // last resort: short id
    (m[`${keyBase}Id`] ? String(m[`${keyBase}Id`]).slice(0, 6) : 'unknown')
  );
}

function fmtWhen(iso: string | Date | undefined) {
  try {
    const d = new Date(iso ?? '');
    if (isNaN(d.getTime())) return '';
    // keep it short; adjust tz if you want local
    return d.toISOString().replace('T', ' ').slice(0, 16);
  } catch {
    return '';
  }
}

const matchHistory: Command = async ({ msg, args, helpers }) => {
  const username = (args[0] ?? '').trim();
  if (!username) {
    await msg.reply('Usage: `!matchHistory <username>`');
    return;
  }

  try {
    const res = await helpers.getJSON(
      `/api/matches/history?username=${encodeURIComponent(username)}`
    );

    const items: any[] = Array.isArray(res?.items) ? res.items : Array.isArray(res) ? res : [];
    if (!items.length) {
      await msg.reply('No matches found.');
      return;
    }

    const lines = items.map((m, i) => {
      const p1 = guessName(m, 'p1');
      const p2 = guessName(m, 'p2');
      const winner = guessName(m, 'winner');
      const when = fmtWhen(m.createdAt);
      const loserScore = typeof m.loserScore === 'number' ? m.loserScore : '?';
      const score = `10-${loserScore}`;
      const prefix = `${i + 1})${when ? ' ' + when : ''}`;
      return `${prefix} — ${p1} vs ${p2} — ${winner} won ${score}`;
    });

    await msg.reply(lines.join('\n'));
  } catch (e: any) {
    const m = (e?.message ?? '').toString();
    await msg.reply(`❌ ${m || 'fetch failed'}`);
  }
};

export default matchHistory;
