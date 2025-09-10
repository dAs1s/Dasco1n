import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { isModOrBroadcaster } from '../lib/permissions.js';

export async function run(client: Client, channel: string, user: ChatUserstate) {
  if (!isModOrBroadcaster(user, channel)) {
    return client.say(channel, `Only mods or the broadcaster can change score.`);
  }
  try {
    const cur = await api.get('/api/matches/current');
    const m = cur.data;
    const p1 = Number(m?.p1Score ?? 0);
    const p2 = Number(m?.p2Score ?? 0) + 1;
    await api.post('/api/matches/current/score', { p1Score: p1, p2Score: p2 });
    return client.say(channel, `Score set to ${p1} : ${p2}`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
