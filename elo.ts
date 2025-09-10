export function expectedScore(ratingA: number, ratingB: number) {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

export function updateElo(ra: number, rb: number, scoreA: 0 | 1, K = 24) {
  const ea = expectedScore(ra, rb);
  const deltaA = K * (scoreA - ea);
  return { a: Math.round(ra + deltaA), b: Math.round(rb - deltaA) };
}
