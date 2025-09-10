
import { NextRequest, NextResponse } from 'next/server';
export function getChannelId(req: NextRequest): string {
  return (req.headers.get('x-channel-id') ?? 'default').toString();
}
export function requireAdmin(req: NextRequest) {
  const header = process.env.API_AUTH_HEADER || 'x-admin-key';
  const token = process.env.API_AUTH_TOKEN || '';
  const got = req.headers.get(header);
  if (!token || !got || got !== token) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }
  return null;
}
