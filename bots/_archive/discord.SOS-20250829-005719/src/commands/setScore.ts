import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { requireModOrAdminFromInteraction, requireModOrAdminFromMessage } from "../lib/permissions.js";

async function set(p1: number, p2: number) {
  await api.post("/api/matches/current/score", { p1Score: p1, p2Score: p2 });
}

export async function runSlash(i: ChatInputCommandInteraction) {
  if (!requireModOrAdminFromInteraction(i)) return i.reply({ content: "Only mods/admins can set score.", ephemeral: true });
  const p1 = i.options.getInteger("p1", true);
  const p2 = i.options.getInteger("p2", true);
  await i.deferReply({ ephemeral: false });
  await set(p1, p2);
  await i.editReply(`Set score to **${p1} : ${p2}**`);
}

export async function runPrefix(msg: Message, args: string[]) {
  if (!requireModOrAdminFromMessage(msg)) return msg.reply("Only mods/admins can set score.");
  const [s1, s2] = args;
  const p1 = Number(s1);
  const p2 = Number(s2);
  if (!Number.isInteger(p1) || !Number.isInteger(p2)) return msg.reply("Usage: `!setScore <p1> <p2>`");
  await set(p1, p2);
  await msg.reply(`Set score to **${p1} : ${p2}**`);
}
