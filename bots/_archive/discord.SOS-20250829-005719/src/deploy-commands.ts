import { REST, Routes, SlashCommandBuilder } from "discord.js";
import "./lib/env.js";

const defs = [
  new SlashCommandBuilder().setName("startbet").setDescription("Start a FT10 bet")
    .addStringOption(o => o.setName("player_a").setDescription("Username A").setRequired(true))
    .addStringOption(o => o.setName("player_b").setDescription("Username B").setRequired(true)),
  new SlashCommandBuilder().setName("bet").setDescription("Place a bet")
    .addIntegerOption(o => o.setName("choice").setDescription("1 or 2").setRequired(true))
    .addIntegerOption(o => o.setName("loser_score").setDescription("Loser score 0-9").setRequired(true))
    .addIntegerOption(o => o.setName("amount").setDescription("Amount of dascoin").setRequired(true)),
  new SlashCommandBuilder().setName("refund").setDescription("Refund your last bet"),
  new SlashCommandBuilder().setName("lockbet").setDescription("Lock further betting"),
  new SlashCommandBuilder().setName("recordresult").setDescription("Record a match result")
    .addIntegerOption(o => o.setName("winner").setDescription("1 or 2").setRequired(true))
    .addIntegerOption(o => o.setName("loser_score").setDescription("0-9").setRequired(true)),
  new SlashCommandBuilder().setName("plus1").setDescription("Increment Player 1 score"),
  new SlashCommandBuilder().setName("plus2").setDescription("Increment Player 2 score"),
  new SlashCommandBuilder().setName("setscore").setDescription("Set exact scores")
    .addIntegerOption(o => o.setName("p1").setDescription("Player 1 score").setRequired(true))
    .addIntegerOption(o => o.setName("p2").setDescription("Player 2 score").setRequired(true)),
  new SlashCommandBuilder().setName("top10ladder").setDescription("Top 10 ELO"),
  new SlashCommandBuilder().setName("top10dascoin").setDescription("Top 10 DasCoin"),
  new SlashCommandBuilder().setName("top10glorpcoin").setDescription("Top 10 GlorpCoin"),
].map(d => d.toJSON());

export async function registerSlashDefinitions() {
  const token = process.env.DISCORD_TOKEN ?? process.env.DISCORD_BOT_TOKEN ?? "";
  const clientId = process.env.DISCORD_CLIENT_ID ?? process.env.DISCORD_APP_ID ?? "";
  const guildId = process.env.DISCORD_GUILD_ID;
  const rest = new REST({ version: "10" }).setToken(token);
  if (!token || !clientId) throw new Error("Missing DISCORD_TOKEN/DISCORD_BOT_TOKEN or DISCORD_CLIENT_ID");
  if (guildId) await rest.put(Routes.applicationGuildCommands(clientId, guildId), { body: defs });
  else       await rest.put(Routes.applicationCommands(clientId), { body: defs });
}
