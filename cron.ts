import cron from 'node-cron';
import { prisma } from '../src/lib/prisma';
import { currentGPCPriceDSC } from '../src/lib/economy';

cron.schedule('31 9 * * 1-5', async () => { // 09:31 ET weekdays
  try {
    const price = await currentGPCPriceDSC();
    const gpc = await prisma.coin.findUniqueOrThrow({ where: { symbol: 'GPC' } });
    await prisma.coinMarket.update({ where: { coinId: gpc.id }, data: { overrideEnabled: false, overridePrice: price.toString() } });
    console.log('GPC price refreshed', price.toString());
  } catch (e) {
    console.error('GPC price refresh failed', e);
  }
}, { timezone: 'America/New_York' });

console.log('Cron worker started.');
