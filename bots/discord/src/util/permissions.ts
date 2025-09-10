// bots/discord/util/permissions.ts
import type { GuildMember } from 'discord.js';

const MOD_ROLE = process.env.DISCORD_MOD_ROLE_ID ?? '';

export async function isMod(member: GuildMember | null): Promise<boolean> {
  if (!member) return false;
  if (member.permissions.has('Administrator')) return true;
  if (MOD_ROLE && member.roles.cache.has(MOD_ROLE)) return true;
  return false;
}
