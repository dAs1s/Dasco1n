import type { Command } from './index';

const deleteMatch: Command = async ({ msg, args, isMod, helpers }) => {
  if (!isMod) return void msg.reply('⛔ Mods only.');
  if (args.length < 2) return void msg.reply('Usage: `!deleteMatch <username> <match#>`');

  const username = args[0].trim();
  const n = Number(args[1]);
  if (!Number.isInteger(n) || n < 1) return void msg.reply('match# must be a positive integer.');

  try {
    // Server expects POST { username, matchNumber }
    const res = await helpers.postJSON('/api/matches/delete', { username, matchNumber: n });
    await msg.reply(`🗑️ Deleted match #${n} for **${username}**.`);
  } catch (e: any) {
    const m = (e?.message ?? '').toString();
    await msg.reply(`❌ ${m || 'delete failed'}`);
  }
};

export default deleteMatch;
