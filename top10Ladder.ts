import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';

export async function run(client: Client, channel: string) {
  try {
    const res = await api.get('/api/leaderboards/elo');
    const items: Array<{ username: string; elo: number }> = res.data?.items ?? res.data ?? [];
    const list = items.slice(0,10).map((u, i) => `${i+1}. ${u.username} (${u.elo})`).join(' | ');
    return client.say(channel, list ? `Top 10 ELO: ${list}` : `No ladder data`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
