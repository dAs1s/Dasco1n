type LastBet = { choice: 1|2; loserScore: number; amount: number; at: number };
const lastBets = new Map<string, LastBet>(); // key by twitch user-id or username

export function setLastBet(userKey: string, bet: LastBet) {
  lastBets.set(userKey, { ...bet, at: Date.now() });
}
export function getLastBet(userKey: string): LastBet | undefined {
  return lastBets.get(userKey);
}
export function clearLastBet(userKey: string) {
  lastBets.delete(userKey);
}
