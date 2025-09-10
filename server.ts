import { z } from "zod";

const schema = z.object({
  DATABASE_URL: z.string().url(),
  SHADOW_DATABASE_URL: z.string().url().optional(),

  // Twitch bot
  TWITCH_BOT_USERNAME: z.string().min(1),
  TWITCH_OAUTH_TOKEN: z.string().min(1), // "oauth:xxxx"
  TWITCH_CHANNELS: z.string().min(1),    // comma separated usernames

  // Discord bot
  DISCORD_BOT_TOKEN: z.string().min(1),
  DISCORD_GUILD_ID: z.string().optional(),

  // misc
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  LOG_LEVEL: z.enum(["fatal","error","warn","info","debug","trace","silent"]).default("info"),
});

export const env = schema.parse(process.env);
