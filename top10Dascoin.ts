import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';

export async function run(client: Client, channel: string) {
  try {
    const res = await api.get('/api/leaderboards/dsc');
    const items: Array<{ username: string; balance: number }> = res.data?.items ?? res.data ?? [];
    const list = items.slice(0,10).map((u, i) => `${i+1}. ${u.username} (${u.balance} DSC)`).join(' | ');
    return client.say(channel, list ? `Top 10 DasCoin: ${list}` : `No DasCoin data`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
