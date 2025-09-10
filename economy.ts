import { prisma } from "./prisma";
import { Decimal } from "./decimal";

export async function currentGPCPriceDSC(): Promise<Decimal> {
  const gpc = await prisma.coin.findUnique({ where: { symbol: "GPC" }, include: { market: true } });
  if (!gpc || !gpc.market) throw new Error("GPC not configured");
  const m = gpc.market;
  if (m.overrideEnabled) return new Decimal(m.overridePrice);
  const price = await fetchDailyOpenSP500();
  return price;
}

// Placeholder SP500 daily open; replace with your vendor
async function fetchDailyOpenSP500(): Promise<Decimal> {
  if (!process.env.ALPHAVANTAGE_API_KEY) return new Decimal(4000);
  try {
    const res = await fetch(`https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=^GSPC&apikey=${process.env.ALPHAVANTAGE_API_KEY}`);
    const json = await res.json();
    const series = json["Time Series (Daily)"];
    const firstKey = Object.keys(series)[0];
    const openStr = series[firstKey]["1. open"];
    return new Decimal(openStr);
  } catch {
    return new Decimal(4000);
  }
}

// Hidden Multiplier (HM) based on circulation (wallet sum) with damping
export async function coinPriceInGPC(coinSymbol: string): Promise<Decimal> {
  const coin = await prisma.coin.findUnique({ where: { symbol: coinSymbol }, include: { market: true } });
  if (!coin || !coin.market) throw new Error("Coin not found");
  const base = new Decimal(coin.basePrice);
  let hm = new Decimal(coin.market.hmValue);
  if (coin.market.hmEnabled) {
    const circRow = await prisma.wallet.aggregate({ _sum: { balance: true }, where: { coinId: coin.id } });
    const circulation = new Decimal(circRow._sum.balance ?? 0);
    const S = new Decimal(100);
    const alpha = new Decimal(0.1);
    const computed = new Decimal(1).plus(alpha.mul(Decimal.log10(new Decimal(1).plus(circulation.div(S)))));
    // EMA damping 0.7 old + 0.3 new
    hm = hm.mul(0.7).plus(computed.mul(0.3));
    await prisma.coinMarket.update({ where: { coinId: coin.id }, data: { hmValue: hm.toString() } });
  }
  return base.mul(hm);
}
