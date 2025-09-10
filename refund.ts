import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { clearLastBet } from '../lib/state.js';

export async function run(client: Client, channel: string, user: ChatUserstate) {
  const username = user['display-name'] || user.username || 'user';
  try {
    await api.post('/api/bets/current/refund', {
      source: 'twitch',
      user: { twitchId: user['user-id'], username },
    });
    clearLastBet(user['user-id'] || username);
    return client.say(channel, `@${username}, your last bet was refunded.`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
