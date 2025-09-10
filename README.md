# Dasco1n Twitch Bot

A tmi.js-based Twitch chat bot that mirrors your Discord & Twitch command set,
delegates core logic to your API, and (optionally) pre-checks StreamElements balances for DasCoin.

## Commands
- !startBet A B
- !bet <1|2> <loserScore 0-9> <amount>
- !refund
- !lockBet
- !recordResult <1|2> <loserScore 0-9>
- !1
- !2
- !setScore <p1> <p2>
- !top10Ladder
- !top10dascoin
- !top10Glorpcoin

## Setup
1) Copy `.env.example` to `.env` and fill in values.
2) Install deps:
   ```bash
   pnpm i   # or npm i / yarn
   ```
3) Run the bot:
   ```bash
   pnpm run dev
   ```

> Notes: StreamElements precheck is optional and only used to validate the user has enough DasCoin before calling your API. The **actual** points movement should occur server-side to avoid race conditions.
