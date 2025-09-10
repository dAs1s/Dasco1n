import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { isModOrBroadcaster } from '../lib/permissions.js';

export async function run(client: Client, channel: string, user: ChatUserstate) {
  if (!isModOrBroadcaster(user, channel)) {
    return client.say(channel, `Only mods or the broadcaster can lock bets.`);
  }
  try {
    await api.post('/api/matches/current/lock', {});
    return client.say(channel, `Bets are now locked.`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
