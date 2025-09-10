import 'dotenv/config';

const raw = (process.env.DISCORD_BOT_TOKEN ?? '').trim().replace(/^['"]|['"]$/g, '').replace(/^Bot\s+/i, '');
if (!raw) {
  console.error('No DISCORD_BOT_TOKEN in env'); process.exit(1);
}

(async () => {
  const res = await fetch('https://discord.com/api/v10/users/@me', {
    headers: { Authorization: `Bot ${raw}` },
  });
  const text = await res.text();
  console.log('status:', res.status, 'ok:', res.ok);
  console.log(text);
})();
