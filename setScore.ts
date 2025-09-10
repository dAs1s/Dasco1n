import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { isModOrBroadcaster } from '../lib/permissions.js';

export async function run(client: Client, channel: string, user: ChatUserstate, args: string[]) {
  if (!isModOrBroadcaster(user, channel)) {
    return client.say(channel, `Only mods or the broadcaster can set score.`);
  }
  const [s1, s2] = args;
  const p1 = Number(s1), p2 = Number(s2);
  if (!Number.isInteger(p1) || !Number.isInteger(p2)) return client.say(channel, `Usage: !setScore <p1> <p2>`);
  try {
    await api.post('/api/matches/current/score', { p1Score: p1, p2Score: p2 });
    return client.say(channel, `Score set to ${p1} : ${p2}`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
