import type { ChatInputCommandInteraction, Message } from 'discord.js';
import { PermissionFlagsBits } from 'discord.js';
export function requireModOrAdminFromMessage(msg: Message): boolean {
  const perms = msg.member?.permissions;
  return !!perms && (perms.has(PermissionFlagsBits.Administrator) || perms.has(PermissionFlagsBits.ManageGuild));
}
export function requireModOrAdminFromInteraction(i: ChatInputCommandInteraction): boolean {
  const p = (i.member as any)?.permissions;
  return !!p && (p.has(PermissionFlagsBits.Administrator) || p.has(PermissionFlagsBits.ManageGuild));
}
