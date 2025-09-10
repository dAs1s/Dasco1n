import { ChatInputCommandInteraction, Message } from "discord.js";
import { api } from "../lib/api.js";

export async function runSlash(i: ChatInputCommandInteraction) {
  await i.deferReply({ ephemeral: false });
  const res = await api.get("/api/leaderboards/elo");
  const items: Array<{ username: string; elo: number }> = res.data?.items ?? res.data ?? [];
  const text = items.slice(0, 10).map((u, idx) => `${idx + 1}. ${u.username} — ELO ${u.elo}`).join("\n");
  await i.editReply("**Top 10 ELO**\n" + (text || "No data"));
}

export async function runPrefix(msg: Message) {
  const res = await api.get("/api/leaderboards/elo");
  const items: Array<{ username: string; elo: number }> = res.data?.items ?? res.data ?? [];
  const text = items.slice(0, 10).map((u, idx) => `${idx + 1}. ${u.username} — ELO ${u.elo}`).join("\n");
  await msg.reply("**Top 10 ELO**\n" + (text || "No data"));
}
