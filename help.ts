// bots/discord/commands/help.ts
import type { Command } from './index';

const help: Command = async ({ msg }) => {
  const lines = [
    '**Commands**',
    '',
    '**Linking & Profiles**',
    '`!inputUser <username> <twitchId> <@discord|id>`',
    '`!inputPlayer <username>`',
    '`!inputDiscordName <username> <@mention|id>`',
    '`!inputTwitchName <username> <twitchId>`',
    '`!setPfP <coinName>` (coming soon)',
    '',
    '**Info**',
    '`!myStats` / `!stats <username>`',
    '`!myWallet`',
    '`!search <query>`',
    '`!top10DSC` | `!top10GPC` | `!top10Ladder` | `!ladder [n]`',
    '`!myMatchHistory` | `!matchHistory <username>`',
    '`!listAll`',
    '',
    '**Betting & Matches**',
    '`!bet <1|2> <loserScore> <amount>`',
    '`!record <p1> <p2> <loserScore>` (mod)',
    '`!remove <p1> <p2> <loserScore>` (mod)',
    '`!deleteMatch <username> <match#>` (mod)',
    '`!deleteUser <username>` (mod)',
  ];
  await msg.reply(lines.join('\n'));
};

export default help;
