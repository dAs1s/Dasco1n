import { NextRequest } from "next/server";

export function requireModOrBroadcaster(_req: NextRequest) {
  // Placeholder: wire to session/roles if needed.
  return true;
}
