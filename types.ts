export type MatchWithTotals = {
  id: string;
  p1UserId: string; p2UserId: string; state: string;
  totals: { p1: number; p2: number };
};
