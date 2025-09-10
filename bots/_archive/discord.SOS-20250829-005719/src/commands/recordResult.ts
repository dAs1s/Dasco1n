import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { requireModOrAdminFromInteraction, requireModOrAdminFromMessage } from "../lib/permissions.js";

export async function runSlash(i: ChatInputCommandInteraction) {
  if (!requireModOrAdminFromInteraction(i)) return i.reply({ content: "Only mods/admins can record results.", ephemeral: true });
  const winner = i.options.getInteger("winner", true);
  const loserScore = i.options.getInteger("loser_score", true);
  await i.deferReply({ ephemeral: false });
  await api.post("/api/matches/current/record", { winner, loserScore });
  await i.editReply(`Result recorded: Winner **${winner}**, Loser score **${loserScore}**.`);
}

export async function runPrefix(msg: Message, args: string[]) {
  if (!requireModOrAdminFromMessage(msg)) return msg.reply("Only mods/admins can record results.");
  const [sW, sL] = args;
  const winner = Number(sW);
  const loserScore = Number(sL);
  if (![1, 2].includes(winner) || !(Number.isInteger(loserScore) && loserScore >= 0 && loserScore <= 9)) {
    return msg.reply("Usage: `!recordResult <1|2> <loserScore 0-9>`");
  }
  await api.post("/api/matches/current/record", { winner, loserScore });
  await msg.reply(`Result recorded: Winner **${winner}**, Loser score **${loserScore}**.`);
}
