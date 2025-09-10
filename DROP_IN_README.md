# Drop-in bundle instructions

This archive includes:
- Updated **bots/discord** (Discord bot, TS, slash + prefix parity)
- Updated **bots/twitch** (Twitch tmi.js bot)
- Updated **app/api** routes that enforce **DB usernames** for bets, channel-scoped matches, and simple leaderboards.

## How to use
1) Unzip this archive at your repo root (replace/merge your existing files).
2) Review `_backup/` for any files that were moved aside due to conflicts.
3) Ensure your API env includes:
   - `API_AUTH_HEADER=x-admin-key`
   - `API_AUTH_TOKEN=<your-token>`
4) Ensure each bot has a `.env` (or points to the root `.env`) with:
   - Discord: `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `API_BASE_URL`, `API_AUTH_*`
   - Twitch: `TWITCH_USERNAME`, `TWITCH_OAUTH`, `TWITCH_CHANNEL`, `API_BASE_URL`, `API_AUTH_*`
5) Start API and bots:
   - API: `pnpm dev` (or your Next.js command)
   - Discord bot: `cd bots/discord && pnpm i && pnpm dev`
   - Twitch bot: `cd bots/twitch && pnpm i && pnpm dev`

Backups of replaced files live under `_backup/` with a timestamped folder name.
