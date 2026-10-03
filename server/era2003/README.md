# era2003

The game as North America launched it in late 2003: the base game and Rise of Zilart, a level 75
cap, and none of the later conveniences. Built for the real September 2003 client (run through
[ffxi-native](https://github.com/tagban/ffxi-native)), whose data decides what is in.

## What it does

| piece | how |
| --- | --- |
| Zones | `sql/zone_settings_2003.sql` deletes the 176 zones the 2003 client has no data for; 124 remain (`KEPT_ZONES.txt`). |
| Accounts | `sql/accounts_2003.sql`: new accounts own Rise of Zilart only. |
| Rules | `settings/main.lua.example`: expansions off past RoZ, `RESTRICT_CONTENT` on, level 75, no Trusts, Records of Eminence, home point warps, Mog House 2F and the like, old stat ratios and formulas. |
| Era behaviour | LandSandBoat's own `era` module: its Lua overrides apply because those expansions are now off. |
| Seasonal events | `lua/seasonal_events.lua`: only the Starlight Celebration and the Egg Hunt are checked, each on its own. Strange Happenings' mobs live in removed zones and its error used to abort the whole check, Starlight included. |

How the zone list was chosen: a zone is kept when the 2003 install's English dialogue table for it
(file id 6420 + zone) holds real text. Chains of Promathia and later zones are empty 4-byte tables
in that install; Dynamis, the [S] zones and a few others are stubs. GM Home and Mordion Gaol are
kept for administration.

## Enabling it

1. In `modules/init.txt`:

   ```
   era/lua
   era/data
   era2003
   ```

   LandSandBoat's `era/sql` has drifted from its own schema (it writes columns since removed), and
   one failing statement stops dbtool, so it is applied separately, statement by statement, with
   what no longer fits logged: the Vana'diel 2003 lab's `setup.ps1` does this.

   (and remove `custom/lua/moghouse_auto_grant_trust.lua` if listed: no Trusts in 2003).
2. Copy `modules/era2003/settings/main.lua.example` to `settings/main.lua`. Settings are read before
   modules load, so this one piece cannot come from the module itself. The file only overrides the
   keys it names.
3. Reimport the database with `tools/dbtool.py`: module SQL runs after the base tables, so the
   zone cut and the account default are reapplied on every reimport.

Existing accounts keep their `expansions` value; set it to 2 by hand if they should match.

## Not here yet

Speaking the 2003 client's packet formats. Server-to-client packets can be rewritten from a C++
module (`OnPushPacket`); client-to-server ones are validated against the modern layouts before any
module hook runs, and the login server has no module hooks, so that part needs either a small core
hook or translation in the client host.
