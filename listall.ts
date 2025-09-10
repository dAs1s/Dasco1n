import type { Command } from './index';

const listAll: Command = async ({ msg, helpers }) => {
  try {
    const data = await helpers.getJSON('/api/users/list'); // your list endpoint
    const users = (data.users ?? data ?? []).map((u: any) => u.username)
      .filter(Boolean)
      .sort((a: string, b: string) => a.localeCompare(b));

    if (!users.length) return void msg.reply('No users.');

    // Keep replies under Discord’s 2000-char limit
    const header = `All users (${users.length}):\n`;
    const max = 1900 - header.length;
    let chunk = header;

    for (const name of users) {
      const piece = name + ', ';
      if (chunk.length + piece.length > max) {
        await msg.reply(chunk.replace(/, $/, ''));
        chunk = '';
      }
      chunk += piece;
    }
    if (chunk) await msg.reply(chunk.replace(/, $/, ''));
  } catch (e: any) {
    await msg.reply(`❌ ${e?.message ?? 'fetch failed'}`);
  }
};

export default listAll;
