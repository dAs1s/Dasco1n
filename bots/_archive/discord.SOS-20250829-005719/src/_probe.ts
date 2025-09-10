import "./lib/env.js";
const token = process.env.DISCORD_TOKEN ?? process.env.DISCORD_BOT_TOKEN ?? "";
const clientId = process.env.DISCORD_CLIENT_ID ?? process.env.DISCORD_APP_ID ?? "";
console.log("ROOT .env loaded OK");
console.log("DISCORD_TOKEN length:", token.length);
console.log("DISCORD_CLIENT_ID:", clientId);
console.log("GUILD_ID:", process.env.DISCORD_GUILD_ID || "(none)");
console.log("API_BASE_URL:", process.env.API_BASE_URL);
