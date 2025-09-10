# Stream Stack Diagnostics
- Timestamp: 2025-08-30 16:26:18Z
- Root: $RootPath = C:\Dasco1n
- PowerShell: 5.1.26100.5074
- OS: Microsoft Windows 11 Pro

## Runtimes
- Node: Found=True Version=v22.15.1 NPM=True
- Python: Found=True Version=Python 3.13.7 Pip=True

## Detected Stacks
```json
{
    "Node":  {
                 "Present":  true,
                 "Dependencies":  {
                                      "react":  "^19.1.1",
                                      "prisma":  "^6.15.0",
                                      "tsx":  "^4.19.2",
                                      "typescript":  "^5.6.2",
                                      "winston":  "^3.11.0",
                                      "axios":  "^1.7.9",
                                      "dotenv":  "^16.4.5",
                                      "react-dom":  "^19.1.1",
                                      "tmi.js":  "^1.8.5",
                                      "next":  "^15.5.2",
                                      "zod":  "^3.23.8",
                                      "@prisma/client":  "^6.15.0",
                                      "@types/node":  "^22.7.4",
                                      "discord.js":  "^14.16.3",
                                      "@types/react":  "^19.1.12",
                                      "@types/react-dom":  "^19.1.9"
                                  }
             },
    "Python":  {
                   "Present":  false,
                   "Dependencies":  {

                                    }
               },
    "DotNet":  {
                   "Present":  false,
                   "Packages":  {

                                }
               }
}
```

## Inventory Summary
```json
{
    "Files":  345,
    "Env":  5,
    "JSON":  26,
    "YAML":  4,
    "Node":  6,
    "PythonReq":  0,
    "CsProj":  0,
    "Commands":  38
}
```

## Services
### Twitch
```json
{
    "Present":  true,
    "Issues":  [

               ],
    "Details":  {
                    "Connectivity":  {
                                         "Tcp_irc_chat_twitch_tv_6697":  {
                                                                             "Port":  6697,
                                                                             "Host":  "irc.chat.twitch.tv",
                                                                             "Reachable":  true
                                                                         },
                                         "Tcp_irc_chat_twitch_tv_6667":  {
                                                                             "Port":  6667,
                                                                             "Host":  "irc.chat.twitch.tv",
                                                                             "Reachable":  true
                                                                         }
                                     },
                    "Values":  {
                                   "TWITCH_OAUTH":  "",
                                   "TWITCH_CLIENT_ID":  "",
                                   "oauth":  "oauk8",
                                   "TWITCH_OAUTH_TOKEN":  "oauk8",
                                   "TWITCH_BOT_USERNAME":  "",
                                   "TWITCH_CLIENT_SECRET":  "",
                                   "channels":  "dasns"
                               }
                }
}
```
### Discord
```json
{
    "Present":  true,
    "Issues":  [

               ],
    "Details":  {
                    "Connectivity":  {
                                         "Tcp_discord_com_443":  {
                                                                     "Port":  443,
                                                                     "Host":  "discord.com",
                                                                     "Reachable":  true
                                                                 }
                                     },
                    "Values":  {
                                   "DISCORD_TOKEN":  "MTQNU",
                                   "DISCORD_GUILD_ID":  "13655",
                                   "token":  "MTQNU",
                                   "DISCORD_BOT_TOKEN":  "MTQNU",
                                   "DISCORD_CLIENT_ID":  "14096"
                               }
                }
}
```
### OBS
```json
{
    "Present":  true,
    "Issues":  [

               ],
    "Details":  {
                    "Connectivity":  {
                                         "Tcp_127.0.0.1_4455":  {
                                                                    "Port":  4455,
                                                                    "Host":  "127.0.0.1",
                                                                    "Reachable":  false
                                                                },
                                         "Tcp_127.0.0.1_4444":  {
                                                                    "Port":  4444,
                                                                    "Host":  "127.0.0.1",
                                                                    "Reachable":  false
                                                                }
                                     },
                    "Values":  {
                                   "port":  4455,
                                   "host":  "127.0.0.1",
                                   "password":  null
                               }
                }
}
```
### StreamElements
```json
{
    "Present":  true,
    "Issues":  [

               ],
    "Details":  {
                    "Connectivity":  {
                                         "Tcp_api_streamelements_com_443":  {
                                                                                "Port":  443,
                                                                                "Host":  "api.streamelements.com",
                                                                                "Reachable":  true
                                                                            }
                                     },
                    "Values":  {
                                   "SE_CHANNEL_ID":  "strid",
                                   "SE_JWT":  ""
                               }
                }
}
```

## Node Packages
```json
{
    "Deps":  {
                 "react":  "^19.1.1",
                 "prisma":  "^6.15.0",
                 "tsx":  "^4.20.5",
                 "typescript":  "^5.9.2",
                 "winston":  "^3.10.0",
                 "axios":  "^1.7.9",
                 "dotenv":  "^16.4.5",
                 "react-dom":  "^19.1.1",
                 "tmi.js":  "^1.8.5",
                 "next":  "^15.5.2",
                 "zod":  "^3.23.8",
                 "@prisma/client":  "^6.15.0",
                 "@types/node":  "^22.18.0",
                 "@types/react":  "^19.1.12",
                 "@types/react-dom":  "^19.1.9"
             },
    "Missing":  [
                    "@prisma/client",
                    "axios",
                    "dotenv",
                    "next",
                    "react",
                    "react-dom",
                    "tmi.js",
                    "winston",
                    "zod",
                    "@types/node",
                    "@types/react",
                    "@types/react-dom",
                    "prisma",
                    "tsx",
                    "typescript"
                ],
    "NodeModulesExists":  true,
    "NpmListOutput":  null
}
```

## Python Packages
```json
{
    "Deps":  [

             ],
    "Missing":  [

                ]
}
```
