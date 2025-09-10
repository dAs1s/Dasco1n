import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { requireModOrAdminFromInteraction, requireModOrAdminFromMessage } from "../lib/permissions.js";

export async function runSlash(i: ChatInputCommandInteraction) {
  if (!requireModOrAdminFromInteraction(i)) return i.reply({ content: "Only mods/admins can start bets.", ephemeral: true });
  const a = i.options.getString("player_a", true).trim();
  const b = i.options.getString("player_b", true).trim();
  await i.deferReply({ ephemeral: false });
  await api.post("/api/matches/open", { p1: a, p2: b, channelId: process.env.CHANNEL_ID || "default" });
  await i.editReply(`Bet started: **${a}** vs **${b}**. Place bets with !bet 1|2 <loserScore> <amount>`);
}

export async function runPrefix(msg: Message, args: string[]) {
  if (!requireModOrAdminFromMessage(msg)) return msg.reply("Only mods/admins can start bets.");
  const [a, b] = args;
  if (!a || !b) return msg.reply("Usage: `!startBet <playerA> <playerB>`");
  await api.post("/api/matches/open", { p1: a, p2: b, channelId: process.env.CHANNEL_ID || "default" });
  await msg.reply(`Bet started: **${a}** vs **${b}**.`);
}
