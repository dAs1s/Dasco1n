// bots/discord/commands/myWallet.ts
import type { Command } from './index';

const myWallet: Command = async ({ msg, helpers }) => {
  try {
    // try discord id, fallback username endpoint if needed
    const data = await helpers.getJSON(`/api/users/${encodeURIComponent(msg.author.id)}/wallet`)
      .catch(async () => helpers.getJSON(`/api/users/${encodeURIComponent(msg.author.username)}/wallet`));
    const lines = (data.balances ?? []).map((b: any) => `${b.symbol}: ${b.amount}`);
    await msg.reply(lines.length ? 'Your wallet:\n' + lines.join('\n') : 'Your wallet is empty.');
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};

export default myWallet;
