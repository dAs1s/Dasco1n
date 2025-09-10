import 'dotenv/config';

export const ENV = {
  TWITCH_USERNAME: process.env.TWITCH_USERNAME ?? '',
  TWITCH_CHANNEL: process.env.TWITCH_CHANNEL ?? '',
  TWITCH_OAUTH: process.env.TWITCH_OAUTH ?? '',

  API_BASE_URL: process.env.API_BASE_URL ?? 'http://localhost:3000',
  API_AUTH_HEADER: process.env.API_AUTH_HEADER ?? 'x-admin-key',
  API_AUTH_TOKEN: process.env.API_AUTH_TOKEN ?? '',

  SE_JWT: process.env.SE_JWT ?? '',
  SE_CHANNEL_ID: process.env.SE_CHANNEL_ID ?? '',
  SE_PRECHECK: (process.env.SE_PRECHECK ?? 'true').toLowerCase() !== 'false',

  LOG_LEVEL: process.env.LOG_LEVEL ?? 'info',
};

if (!ENV.TWITCH_USERNAME) throw new Error('TWITCH_USERNAME missing');
if (!ENV.TWITCH_CHANNEL) throw new Error('TWITCH_CHANNEL missing');
if (!ENV.TWITCH_OAUTH) throw new Error('TWITCH_OAUTH missing');
if (!ENV.API_BASE_URL) throw new Error('API_BASE_URL missing');
