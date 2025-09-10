// bots/discord/commands/inputTwitchName.ts
import type { Command } from './index';

const inputTwitchName: Command = async ({ msg, args, helpers }) => {
  if (args.length < 2) return void msg.reply('Usage: `!inputTwitchName <username> <twitchLogin>`');
  const [username, twitchLogin] = args;
  try {
    // per your final convention, write to twitchId (login string or numeric id if you later map it)
    await helpers.patchJSON(`/api/users/${encodeURIComponent(username)}`, { twitchId: twitchLogin });
    await msg.reply(`🔗 Linked **${username}** ⇄ Twitch **${twitchLogin}** (saved as twitchId)`);
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default inputTwitchName;
