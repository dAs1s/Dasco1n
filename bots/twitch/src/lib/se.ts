import axios from "axios";
import { ENV } from "./env.js";

export async function hasEnoughDascoin(username: string, amount: number): Promise<boolean> {
  if (!ENV.SE_PRECHECK) return true; // disabled by env
  if (!ENV.SE_JWT || !ENV.SE_CHANNEL_ID) return true; // silently allow if not configured

  try {
    const url = `https://api.streamelements.com/kappa/v2/points/${ENV.SE_CHANNEL_ID}/${encodeURIComponent(username)}`;
    const res = await axios.get(url, { headers: { Authorization: `Bearer ${ENV.SE_JWT}` }, timeout: 10000 });
    const balance = Number(res.data?.points ?? res.data?.balance ?? 0);
    return balance >= amount;
  } catch {
    // If SE is down or user not found, allow and let your API be source of truth
    return true;
  }
}
