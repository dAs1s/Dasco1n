import "../lib/env.js";
import axios from "axios";

export const API_BASE = process.env.API_BASE_URL ?? "http://127.0.0.1:3000";
const AUTH_HEADER = process.env.API_AUTH_HEADER ?? "x-admin-key";
const AUTH_TOKEN  = process.env.API_AUTH_TOKEN ?? "";
const CHANNEL_ID  = process.env.CHANNEL_ID ?? "default";

function buildHeaders(extra: Record<string, string> = {}) {
  const h: Record<string, string> = { "x-channel-id": CHANNEL_ID, ...extra };
  if (AUTH_TOKEN) h[AUTH_HEADER] = AUTH_TOKEN;
  return h;
}

export async function getJSON(path: string) {
  const res = await axios.get(`${API_BASE}${path}`, { headers: buildHeaders() });
  return res.data;
}

export async function postJSON(path: string, body: any) {
  const res = await axios.post(`${API_BASE}${path}`, body, {
    headers: { "Content-Type": "application/json", ...buildHeaders() },
  });
  return res.data;
}

export async function patchJSON(path: string, body: any) {
  const res = await axios.patch(`${API_BASE}${path}`, body, {
    headers: { "Content-Type": "application/json", ...buildHeaders() },
  });
  return res.data;
}

export async function delJSON(path: string, body?: any) {
  const res = await axios.delete(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json", ...buildHeaders() },
    data: body,
  });
  return res.data;
}
