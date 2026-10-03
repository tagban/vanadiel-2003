# The lab

A local Vana'diel 2003 setup for testing: a private database, the LandSandBoat server with
`era2003`, and (once it can play) the 2003 client, behind one launcher.

| | |
| --- | --- |
| `setup.ps1` | one-time: makes the lab folder, its database (its own MariaDB instance on port 33062, local only), imports LandSandBoat with era2003, and puts **Vana'diel 2003** on the desktop |
| `Vanadiel2003.ps1` | the launcher: starts what is not running - database, then the server (connect, world, map) - then the client; `-Server`, `-Status`, `-Stop` |

## What works

- **Server: yes.** 124 zones (base game and Rise of Zilart), level 75, no Trusts or later
  conveniences, LandSandBoat's era reverts, and the seasonal events of the time (Starlight
  Celebration, Egg Hunt). Logs are in `logs\`.
- **Client: not yet.** The September 2003 client is unpacked, recompiled and boots under ffxi-native
  (its `DllMain` runs, `GameMain` is created), but it cannot sign in: it speaks the 2003 lobby and
  packet protocol, which LandSandBoat does not. Until the translation exists the launcher starts the
  server and says so. When `game\host64.exe` is there, it starts that too.

## Notes

- The server runs from the LandSandBoat checkout named in `lab.json`; its `settings\main.lua`
  carries the 2003 rules, so anything else run from that checkout gets them too.
- `lab-credentials.json` holds the lab database's passwords. The database only listens on
  127.0.0.1.
- What LandSandBoat's era SQL could not apply (columns its schema no longer has, all for content
  after 2003) is in `logs\era-sql.log`.
