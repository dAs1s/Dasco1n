import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { requireModOrAdminFromInteraction, requireModOrAdminFromMessage } from "../lib/permissions.js";

export async function runSlash(i: ChatInputCommandInteraction) {
  if (!requireModOrAdminFromInteraction(i)) return i.reply({ content: "Only mods/admins can lock bets.", ephemeral: true });
  await i.deferReply({ ephemeral: false });
  await api.post("/api/matches/current/lock", {});
  await i.editReply("Bets are now locked.");
}

export async function runPrefix(msg: Message) {
  if (!requireModOrAdminFromMessage(msg)) return msg.reply("Only mods/admins can lock bets.");
  await api.post("/api/matches/current/lock", {});
  await msg.reply("Bets are now locked.");
}
