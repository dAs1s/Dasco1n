import { Decimal } from "./decimal";

export type PayoutInputs = {
  betAmountDSC: number; // integer
  totalOnWinner: number; // integer
  totalOnLoser: number;  // integer
  comboStacks: number;   // 0..10
  isPerfect: boolean;
  isUnderdog: boolean; // informational; DSC payout unaffected (lottery handled elsewhere)
};

export function computePayout({
  betAmountDSC,
  totalOnWinner,
  totalOnLoser,
  comboStacks,
  isPerfect,
  isUnderdog,
}: PayoutInputs) {
  const bet = new Decimal(betAmountDSC);
  // Protect against zero division
  const ratio = new Decimal(totalOnLoser <= 0 ? 1 : totalOnLoser).div(new Decimal(Math.max(1, totalOnWinner)));
  const base = bet.mul(ratio);
  // Step cap: min 5%, max 10x
  const minGain = bet.mul(0.05);
  const maxGain = bet.mul(10);
  let payout = Decimal.max(minGain, Decimal.min(base, maxGain));

  // Multipliers
  const comboMult = new Decimal(1).plus(new Decimal(0.015).mul(Math.min(10, Math.max(0, comboStacks)))); // up to +15%
  payout = payout.mul(comboMult);
  if (isPerfect) payout = payout.mul(2);

  // Final hard cap 10x bet
  payout = Decimal.min(payout, maxGain);
  return payout.floor().toNumber();
}
