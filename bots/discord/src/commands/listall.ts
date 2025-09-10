import { getJSON, postJSON, API_BASE } from '../lib/http';
import type { Command } from "./index";

const listAll: Command = async ({ msg, helpers }) => {
  try {
    const { items = [] } = await getJSON(`/api/leaderboards/elo?limit=1000`);
    if (!items.length) {
      await msg.reply("No users found on the ladder.");
      return;
    }
    const lines = items.map((u: any, i: number) => `${String(i + 1).padStart(3, " ")}. ${u.username} — ${u.elo}`);

    // Send in chunks to avoid 2000-char message limit
    const CHUNK = 40;
    for (let i = 0; i < lines.length; i += CHUNK) {
      const slice = lines.slice(i, i + CHUNK).join("\n");
      await msg.channel.send(`**Ladder (ELO)**\n${slice}`);
    }
  } catch (err) {
    console.error("!listall error:", err);
    try { await msg.reply("Failed to fetch ladder."); } catch {}
  }
};

export default listAll;
