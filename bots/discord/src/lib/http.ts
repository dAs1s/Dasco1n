/* src/lib/http.ts */
const rawBase = (process.env.API_BASE || 'http://127.0.0.1:3000').trim();
export const API_BASE = rawBase.replace(/\/+$/, '');

export async function getJSON<T = any>(path: string): Promise<T> {
  const url = `${API_BASE}${path}`;
  const res = await fetch(url, { method: 'GET', headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<T>;
}

export async function postJSON<T = any>(path: string, body: any): Promise<T> {
  const url = `${API_BASE}${path}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', accept: 'application/json' },
    body: JSON.stringify(body ?? {})
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<T>;
}