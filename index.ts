import 'dotenv/config';
import tmi from 'tmi.js';
import { ENV } from './lib/env.js';
import { logger } from './lib/logger.js';

import * as startBet from './commands/startBet.js';
import * as bet from './commands/bet.js';
import * as refund from './commands/refund.js';
import * as lockBet from './commands/lockBet.js';
import * as recordResult from './commands/recordResult.js';
import * as plus1 from './commands/plus1.js';
import * as plus2 from './commands/plus2.js';
import * as setScore from './commands/setScore.js';
import * as top10Ladder from './commands/top10Ladder.js';
import * as top10Dascoin from './commands/top10Dascoin.js';
import * as top10Glorpcoin from './commands/top10Glorpcoin.js';

const PREFIX = '!';

const client = new tmi.Client({
  options: { debug: false },
  connection: { reconnect: true, secure: true },
  identity: {
    username: ENV.TWITCH_USERNAME,
    password: ENV.TWITCH_OAUTH,
  },
  channels: [ENV.TWITCH_CHANNEL],
});

const router: Record<string, Function> = {
  'startbet': startBet.run,
  'bet': bet.run,
  'refund': refund.run,
  'lockbet': lockBet.run,
  'recordresult': recordResult.run,
  '1': plus1.run,
  '2': plus2.run,
  'setscore': setScore.run,
  'top10ladder': top10Ladder.run,
  'top10dascoin': top10Dascoin.run,
  'top10glorpcoin': top10Glorpcoin.run,
};

client.on('message', async (channel, userstate, message, self) => {
  if (self) return;
  if (!message.startsWith(PREFIX)) return;

  const parts = message.slice(PREFIX.length).trim().split(/\s+/);
  const cmd = (parts.shift() || '').toLowerCase();
  const handler = router[cmd];
  if (!handler) return;

  try {
    await handler(client, channel, userstate, parts);
  } catch (e: any) {
    const msg = e?.message ?? 'Unknown error';
    logger.error(`[${cmd}] ${msg}`);
    await client.say(channel, `Error: ${msg}`);
  }
});

client.on('connected', () => logger.info(`[TMI] Connected as ${ENV.TWITCH_USERNAME} -> #${ENV.TWITCH_CHANNEL}`));
client.on('disconnected', (reason) => logger.warn(`[TMI] Disconnected: ${reason}`));

client.connect().catch(err => {
  logger.error('Failed to connect to Twitch:', err);
  process.exit(1);
});
