import type { ChatUserstate, Client } from 'tmi.js';
import { api } from '../lib/api.js';
import { isModOrBroadcaster } from '../lib/permissions.js';

export async function run(client: Client, channel: string, user: ChatUserstate, args: string[]) {
  if (!isModOrBroadcaster(user, channel)) {
    return client.say(channel, `Only mods or the broadcaster can record results.`);
  }
  const [sW, sL] = args;
  const winner = Number(sW), loserScore = Number(sL);
  if (![1,2].includes(winner) || !(Number.isInteger(loserScore) && loserScore >= 0 && loserScore <= 9)) {
    return client.say(channel, `Usage: !recordResult <1|2> <loserScore 0-9>`);
  }
  try {
    await api.post('/api/matches/current/record', { winner, loserScore });
    return client.say(channel, `Result recorded: Winner ${winner}, Loser score ${loserScore}.`);
  } catch (e: any) {
    const msg = e?.response?.data?.message ?? e?.message ?? 'error';
    return client.say(channel, `Error: ${msg}`);
  }
}
