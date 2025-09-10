import path from "node:path";
import fs from "node:fs";
import dotenv from "dotenv";

/** Force-load the ROOT .env (C:\\Dasco1n\\.env) */
const ROOT_ENV = path.resolve(process.cwd(), "..", "..", ".env");
if (fs.existsSync(ROOT_ENV)) {
  dotenv.config({ path: ROOT_ENV });
} else {
  dotenv.config();
}

export const ENV = {
  TWITCH_BOT_USERNAME: process.env.TWITCH_BOT_USERNAME ?? "",
  TWITCH_OAUTH_TOKEN:  process.env.TWITCH_OAUTH_TOKEN ?? "",
  TWITCH_CHANNELS:     (process.env.TWITCH_CHANNELS ?? "").split(",").map(s => s.trim()).filter(Boolean),
  API_BASE_URL:        process.env.API_BASE_URL ?? "http://127.0.0.1:3000",
  API_AUTH_HEADER:     process.env.API_AUTH_HEADER ?? "x-admin-key",
  API_AUTH_TOKEN:      process.env.API_AUTH_TOKEN ?? "",
  CHANNEL_ID:          process.env.CHANNEL_ID ?? "default",
  // StreamElements (optional precheck)
  SE_JWT:              process.env.SE_JWT ?? "",
  SE_CHANNEL_ID:       process.env.SE_CHANNEL_ID ?? "",
  SE_PRECHECK:         /^true$/i.test(process.env.SE_PRECHECK ?? "true"),
};

if (!ENV.TWITCH_BOT_USERNAME) throw new Error("TWITCH_BOT_USERNAME missing in C:\\Dasco1n\\.env");
if (!ENV.TWITCH_OAUTH_TOKEN)  throw new Error("TWITCH_OAUTH_TOKEN missing in C:\\Dasco1n\\.env");
if (ENV.TWITCH_CHANNELS.length === 0) throw new Error("TWITCH_CHANNELS missing/empty in C:\\Dasco1n\\.env");
