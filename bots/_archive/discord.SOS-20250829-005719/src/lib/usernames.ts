import type { User } from 'discord.js';
export function toDbUsername(user: User): string { return user.username; }
