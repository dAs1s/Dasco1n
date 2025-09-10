import type { Command } from './index';

const deleteUser: Command = async ({ msg, args, isMod, helpers }) => {
  if (!isMod) return void msg.reply('⛔ Mods only.');
  const username = args[0];
  if (!username) return void msg.reply('Usage: `!deleteUser <username>`');

  try {
    await helpers.delJSON(`/api/users/${encodeURIComponent(username)}`);
    await msg.reply(`🗑️ Deleted **${username}**`);
  } catch (e: any) {
    await msg.reply(`❌ ${e?.message ?? 'delete failed'}`);
  }
};

export default deleteUser;
