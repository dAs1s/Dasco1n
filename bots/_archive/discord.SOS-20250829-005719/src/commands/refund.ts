import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { toDbUsername } from "../lib/usernames.js";

async function refund(username: string) {
  const res = await api.post("/api/bets/current/refund", { username }, { headers: { "x-username": username } });
  return res.data;
}

export async function runSlash(i: ChatInputCommandInteraction) {
  await i.deferReply({ ephemeral: true });
  await refund(toDbUsername(i.user));
  await i.editReply("Your last bet was refunded and overlay updated.");
}

export async function runPrefix(msg: Message) {
  await refund(toDbUsername(msg.author));
  await msg.reply("Your last bet was refunded and overlay updated.");
}
