import { getJSON, postJSON, API_BASE } from '../lib/http';
import type { Command } from "./index";

// Keep as a stub until your API exposes the endpoint you want to hit.
const removeCmd: Command = async ({ msg }) => {
  await msg.reply("`!remove` isn’t wired yet: add a removal endpoint to your API and I’ll wire this command to it.");
};

export default removeCmd;
