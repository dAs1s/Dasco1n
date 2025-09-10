import { getJSON, postJSON, API_BASE } from '../lib/http';
// bots/discord/commands/myWallet.ts
import type { Command } from './index';

const myWallet: Command = async ({ msg, helpers }) => {
  try {
    const data = await getJSON(`/api/wallets/${encodeURIComponent(msg.author.id)}`);
    const rows = data.items ?? data.wallet ?? data ?? [];
    if (!rows.length) return void msg.reply('No wallets found.');
    const lines = rows.map((w: any) => `${w.symbol ?? w.coin ?? '?'}: ${w.balance ?? w.amount ?? 0}`);
    await msg.reply('```\n' + lines.join('\n') + '\n```');
  } catch (e: any) {
    await msg.reply(`❌ ${e.message}`);
  }
};
export default myWallet;
