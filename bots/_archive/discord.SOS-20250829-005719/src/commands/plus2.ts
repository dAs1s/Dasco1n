import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";
import { requireModOrAdminFromInteraction, requireModOrAdminFromMessage } from "../lib/permissions.js";

async function inc() {
  const cur = await api.get("/api/matches/current");
  const m = cur.data?.match ?? {};
  const p1 = Number(m?.scoreP1 ?? 0);
  const p2 = Number(m?.scoreP2 ?? 0) + 1;
  await api.post("/api/matches/current/score", { p1Score: p1, p2Score: p2 });
}

export async function runSlash(i: ChatInputCommandInteraction) {
  if (!requireModOrAdminFromInteraction(i)) return i.reply({ content: "Only mods/admins can change score.", ephemeral: true });
  await i.deferReply({ ephemeral: false });
  await inc();
  await i.editReply("Incremented Player 2 score by 1.");
}

export async function runPrefix(msg: Message) {
  if (!requireModOrAdminFromMessage(msg)) return msg.reply("Only mods/admins can change score.");
  await inc();
  await msg.reply("Incremented Player 2 score by 1.");
}
