// bots/diag/discord-canary.ts
import 'dotenv/config';
import { Client, GatewayIntentBits, Partials, Events } from 'discord.js';

const client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent],
  partials: [Partials.Channel],
});

client.once(Events.ClientReady, (c) => console.log('Ready as', c.user.tag));
client.on(Events.MessageCreate, async (msg) => {
  if (msg.author.bot || !msg.guild) return;
  if (msg.content === '!ping') await msg.reply('pong');
});

client.login(process.env.DISCORD_BOT_TOKEN);
