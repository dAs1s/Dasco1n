import axios from 'axios';
import { ENV } from './env.js';

const BASE = 'https://api.streamelements.com/kappa/v2';

function authHeaders() {
  if (!ENV.SE_JWT) return {};
  return { Authorization: `Bearer ${ENV.SE_JWT}` };
}

export async function getPoints(username: string) {
  if (!ENV.SE_JWT || !ENV.SE_CHANNEL_ID) {
    return { available: Infinity }; // skip check if not configured
  }
  const url = `${BASE}/points/${ENV.SE_CHANNEL_ID}/${encodeURIComponent(username)}`;
  const res = await axios.get(url, { headers: authHeaders() });
  // Response shape may vary; we only need "points" or similar numeric field.
  const points = res.data?.points ?? res.data?.total ?? 0;
  return { available: Number(points) };
}
