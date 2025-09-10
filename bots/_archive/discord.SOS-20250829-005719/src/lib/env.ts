import path from "node:path";
import fs from "node:fs";
import dotenv from "dotenv";

/** Force-load the ROOT .env (C:\Dasco1n\.env) */
const ROOT_ENV = path.resolve(process.cwd(), "..", "..", ".env");
if (fs.existsSync(ROOT_ENV)) {
  dotenv.config({ path: ROOT_ENV });
} else {
  dotenv.config();
}

export const ENV = {
  // prefer DISCORD_TOKEN if non-empty, else fall back to DISCORD_BOT_TOKEN
  DISCORD_TOKEN: (process.env.DISCORD_TOKEN && process.env.DISCORD_TOKEN.trim() !== "" ? process.env.DISCORD_TOKEN : (process.env.DISCORD_BOT_TOKEN || "")),
  DISCORD_CLIENT_ID: process.env.DISCORD_CLIENT_ID ?? process.env.DISCORD_APP_ID ?? "",
  DISCORD_GUILD_ID: process.env.DISCORD_GUILD_ID ?? "",
  API_BASE_URL: process.env.API_BASE_URL ?? "http://127.0.0.1:3000",
  API_AUTH_HEADER: process.env.API_AUTH_HEADER ?? "x-admin-key",
  API_AUTH_TOKEN: process.env.API_AUTH_TOKEN ?? "",
  CHANNEL_ID: process.env.CHANNEL_ID ?? "default",
  LOG_LEVEL: process.env.LOG_LEVEL ?? "info",
};

if (!ENV.DISCORD_TOKEN) {
  throw new Error("DISCORD_TOKEN missing (set DISCORD_BOT_TOKEN or DISCORD_TOKEN in C:\\Dasco1n\\.env)");
}
if (!ENV.DISCORD_CLIENT_ID) {
  throw new Error("DISCORD_CLIENT_ID missing in C:\\Dasco1n\\.env");
}

export default ENV;
