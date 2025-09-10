// bots/discord/util/parsing.ts
export function parseMentionOrId(input: string): string | null {
  const m = input.match(/^<@!?(\d+)>$/);
  if (m) return m[1];
  if (/^\d{15,21}$/.test(input)) return input;
  return null;
}
