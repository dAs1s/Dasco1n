import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { getPoints } from '../lib/streamelements.js';
import { setLastBet } from '../lib/state.js';

export async function run(client: Client, channel: string, user: ChatUserstate, args: string[]) {
  const [sChoice, sLoser, sAmt] = args;
  const choice = Number(sChoice);
  const loserScore = Number(sLoser);
  const amount = Number(sAmt);
  if (![1, 2].includes(choice) || !Number.isInteger(loserScore) || !Number.isFinite(amount)) {
    return client.say(channel, `Usage: !bet <1|2> <loserScore 0-9> <amount>`);
  }
  // Optional StreamElements precheck
  try {
    const username = user['display-name'] || user.username || '';
    if (!username) return client.say(channel, `Unknown user.`);

    // Precheck: ensure user has enough DSC
    const { available } = await getPoints(username);
    if (Number.isFinite(available) && available < amount) {
      return client.say(channel, `@${username}, insufficient DasCoin (have ${available}, need ${amount}).`);
    }

    const payload = {
      choice, loserScore, amount,
      source: 'twitch',
      user: { twitchId: user['user-id'], username },
    };
    await api.post('/api/bets/current/place', payload);
    setLastBet(user['user-id'] || username, { choice: choice as 1|2, loserScore, amount, at: Date.now() });
    return client.say(channel, `Bet accepted: @${username} on player ${choice}, loser score ${loserScore}, amount ${amount} DSC.`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
