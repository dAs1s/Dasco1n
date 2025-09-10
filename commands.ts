import { z } from "zod";

export type CommandCtx = {
  platform: "twitch" | "discord";
  userId: string;
  username: string;
  isMod: boolean;
  isBroadcaster: boolean;
  channelId?: string;
  callApi: (path: string, init?: RequestInit) => Promise<any>;
  reply: (msg: string) => Promise<void>;
};

export async function handleCommand(ctx: CommandCtx, raw: string) {
  const [cmd, ...args] = raw.trim().split(/\s+/);
  const low = cmd.toLowerCase();

  try {
    switch (low) {
      case "!help":
        return ctx.reply(modHelp(ctx));
      case "!wallet":
        return showWallet(ctx);
      case "!stats":
        return showStats(ctx, args.join(" "));
      case "!bet":
        return betHandler(ctx, args);
      case "!lock":
        return lockHandler(ctx);
      case "!record":
        return recordHandler(ctx, args);
      case "!score":
        return scoreHandler(ctx, args);
      case "!replacebet":
        return replaceBetHandler(ctx, args);
      case "!cancelbet":
        return cancelBetHandler(ctx);
      case "!buygpc":
        return buyGPC(ctx, args);
      case "!sellgpc":
        return sellGPC(ctx, args);
      case "!offer":
        return offerCreate(ctx, args);
      case "!accept":
        return offerAccept(ctx, args);
      default:
        return;
    }
  } catch (e: any) {
    return ctx.reply(`Error: ${e.message ?? e}`);
  }
}

function modHelp(ctx: CommandCtx) {
  const base = [
    "!wallet | !stats [user] | !help",
    "!bet 1 <loserScore> <amount>  — place bet",
    "!replacebet <amount> | !cancelbet",
    "!buygpc <amount> | !sellgpc <amount>",
    "!offer <qty> <COIN> @buyer <priceGPC> | !accept <offerId>",
  ];
  if (ctx.isMod || ctx.isBroadcaster) {
    base.push(
      '!bet open "<player1>" "<player2>"',
      "!lock",
      '!record "<player1>" "<player2>" <loserScore>',
      "!score 1 +3 | !score 2 set 9"
    );
  }
  return base.join(" · ");
}

async function showWallet(ctx: CommandCtx) {
  const data = await ctx.callApi(`/api/users/${ctx.userId}/wallet`);
  const items = data.wallet.map((w: any) => `${w.coin}: ${w.display}`);
  return ctx.reply(`Wallet: ${items.join(" | ")}`);
}

async function showStats(ctx: CommandCtx, who: string) {
  const target = who || ctx.username;
  const data = await ctx.callApi(`/api/users/${encodeURIComponent(target)}`);
  return ctx.reply(`Stats for ${data.username}: ELO ${data.elo} (W${data.wins}/L${data.losses})`);
}

async function betHandler(ctx: CommandCtx, args: string[]) {
  if (args[0] === "open") {
    if (!(ctx.isMod || ctx.isBroadcaster)) return ctx.reply("Mods only.");
    const p1 = args[1]?.replaceAll('"', '') ?? "";
    const p2 = args[2]?.replaceAll('"', '') ?? "";
    const res = await ctx.callApi(`/api/matches/open`, {
      method: "POST",
      body: JSON.stringify({ p1, p2, channelId: ctx.channelId }),
    });
    return ctx.reply(`Opened match #${res.matchId} : ${p1} vs ${p2}`);
  }
  // !bet 1 7 200
  const winner = Number(args[0]);
  const loserScore = Number(args[1]);
  const amount = Number(args[2]);
  if (![1, 2].includes(winner) || isNaN(loserScore) || isNaN(amount)) return ctx.reply("Usage: !bet 1 <loserScore> <amount>");
  await ctx.callApi(`/api/bets/current/place`, {
    method: "POST",
    body: JSON.stringify({ predictedWinner: winner === 1 ? "p1" : "p2", predictedLoserScore: loserScore, amountDSC: amount }),
  });
  return ctx.reply(`Bet placed: ${amount} DSC on P${winner} (loser ${loserScore})`);
}

async function replaceBetHandler(ctx: CommandCtx, args: string[]) {
  const amount = Number(args[0]);
  if (!amount) return ctx.reply("Usage: !replacebet <amount>");
  await ctx.callApi(`/api/bets/current/place`, {
    method: "POST",
    body: JSON.stringify({ replace: true, amountDSC: amount }),
  });
  return ctx.reply(`Bet updated to ${amount} DSC.`);
}

async function cancelBetHandler(ctx: CommandCtx) {
  await ctx.callApi(`/api/bets/current/refund`, { method: "POST" });
  return ctx.reply("Bet cancelled (refunded).");
}

async function lockHandler(ctx: CommandCtx) {
  if (!(ctx.isMod || ctx.isBroadcaster)) return ctx.reply("Mods only.");
  await ctx.callApi(`/api/matches/current/lock`, { method: "POST" });
  return ctx.reply("Bets are now LOCKED.");
}

async function recordHandler(ctx: CommandCtx, args: string[]) {
  if (!(ctx.isMod || ctx.isBroadcaster)) return ctx.reply("Mods only.");
  const p1 = args[0]?.replaceAll('"', '');
  const p2 = args[1]?.replaceAll('"', '');
  const loserScore = Number(args[2]);
  if (!p1 || !p2 || isNaN(loserScore)) return ctx.reply('Usage: !record "p1" "p2" <loserScore>');
  await ctx.callApi(`/api/matches/current/record`, { method: "POST", body: JSON.stringify({ p1, p2, loserScore }) });
  return ctx.reply(`Recorded: ${p1} vs ${p2} (${loserScore}).`);
}

async function scoreHandler(ctx: CommandCtx, args: string[]) {
  if (!(ctx.isMod || ctx.isBroadcaster)) return ctx.reply("Mods only.");
  const side = args[0];
  const op = args[1];
  const val = Number(args[2]);
  await ctx.callApi(`/api/matches/current/score`, { method: "POST", body: JSON.stringify({ side: side === '1' ? 'p1' : 'p2', op, val }) });
}

async function buyGPC(ctx: CommandCtx, args: string[]) {
  const amount = Number(args[0]);
  if (!amount) return ctx.reply("Usage: !buygpc <amount>");
  await ctx.callApi(`/api/gpc/buy`, { method: "POST", body: JSON.stringify({ amountGPC: amount }) });
  return ctx.reply(`Bought ${amount} GPC.`);
}

async function sellGPC(ctx: CommandCtx, args: string[]) {
  const amount = Number(args[0]);
  if (!amount) return ctx.reply("Usage: !sellgpc <amount>");
  await ctx.callApi(`/api/gpc/sell`, { method: "POST", body: JSON.stringify({ amountGPC: amount }) });
  return ctx.reply(`Sold ${amount} GPC.`);
}

async function offerCreate(ctx: CommandCtx, args: string[]) {
  // !offer 3 DRAGON @buyer 12.5
  const qty = Number(args[0]);
  const coin = args[1];
  const buyerHandle = args[2];
  const price = Number(args[3]);
  if (!qty || !coin || !buyerHandle || !price) return ctx.reply("Usage: !offer <qty> <COIN> @buyer <priceGPC>");
  const res = await ctx.callApi(`/api/offers/create`, {
    method: "POST",
    body: JSON.stringify({ qty, coin, buyerHandle, priceGPC: price })
  });
  return ctx.reply(`Offer #${res.id} created for ${buyerHandle}. Expires in 5m.`);
}

async function offerAccept(ctx: CommandCtx, args: string[]) {
  const id = args[0];
  if (!id) return ctx.reply("Usage: !accept <offerId>");
  await ctx.callApi(`/api/offers/${id}/accept`, { method: "POST" });
  return ctx.reply(`Offer #${id} accepted.`);
}
