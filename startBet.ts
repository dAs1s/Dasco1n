import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { isModOrBroadcaster } from '../lib/permissions.js';

export async function run(client: Client, channel: string, user: ChatUserstate, args: string[]) {
  if (!isModOrBroadcaster(user, channel)) {
    return client.say(channel, `Only mods or the broadcaster can start bets.`);
  }
  const [a, b] = args;
  if (!a || !b) return client.say(channel, `Usage: !startBet <playerA> <playerB>`);
  try {
    const res = await api.post('/api/matches/open', { p1: a, p2: b, source: 'twitch' });
    const m = res.data;
    return client.say(channel, `Bet started: ${m.p1?.username ?? a} vs ${m.p2?.username ?? b}. Place bets with !bet 1|2 <loserScore> <amount>`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
