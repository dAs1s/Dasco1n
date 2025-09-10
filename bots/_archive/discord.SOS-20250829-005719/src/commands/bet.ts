import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { toDbUsername } from "../lib/usernames.js";

async function place(username: string, choice: number, loserScore: number, amount: number) {
  const payload = { username, choice, loserScore, amount };
  const res = await api.post("/api/bets/current/place", payload, { headers: { "x-username": username } });
  return res.data;
}

export async function runSlash(i: ChatInputCommandInteraction) {
  const choice = i.options.getInteger("choice", true);
  const loserScore = i.options.getInteger("loser_score", true);
  const amount = i.options.getInteger("amount", true);
  await i.deferReply({ ephemeral: true });
  const username = toDbUsername(i.user);
  await place(username, choice, loserScore, amount);
  await i.editReply(`Bet accepted: on player **${choice}**, loser score **${loserScore}**, amount **${amount} DSC**`);
}

export async function runPrefix(msg: Message, args: string[]) {
  const [sChoice, sLoser, sAmt] = args;
  const choice = Number(sChoice);
  const loserScore = Number(sLoser);
  const amount = Number(sAmt);
  if (![1, 2].includes(choice) || !Number.isInteger(loserScore) || !Number.isFinite(amount)) {
    return msg.reply("Usage: `!bet <1|2> <loserScore 0-9> <amount>`");
  }
  const username = toDbUsername(msg.author);
  await place(username, choice, loserScore, amount);
  await msg.reply(`Bet accepted: on player **${choice}**, loser score **${loserScore}**, amount **${amount} DSC**`);
}
