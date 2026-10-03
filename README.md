# Vana'diel 2003

> [!WARNING]
> **For private servers only.** This does not work with retail FINAL FANTASY XI or Square Enix's
> PlayOnline service, and must not be pointed at them. It is not affiliated with, endorsed by, or
> supported by Square Enix. FINAL FANTASY XI and PlayOnline are trademarks of Square Enix; you need
> your own legitimately obtained copy of the game's files.

FINAL FANTASY XI the way North America first played it, in late 2003: the base game and Rise of
Zilart, level 75, no Trusts, no Records of Eminence, no home point warps. The real client of the
time, the September 2003 build, made to run on a modern machine, against a server that plays by the
rules of the time. Self-hosted: one folder holds the launcher, the game it makes, and your server.

## How it fits together

| piece | what it is | where |
| --- | --- | --- |
| the client | the September 2003 `FFXiMain.dll` / `FFXi.dll`, statically recompiled from x86 to C and compiled on your machine | [ffxi-native](https://github.com/tagban/ffxi-native) (submodule), build `2003-09-05` |
| the server | LandSandBoat with the `era2003` module: zones, rules and accounts of late 2003 | [`server/era2003`](server/era2003) |
| the launcher | finds your 2003 install, makes the game for it, starts the server and the game | `launcher/` (to come) |

The 2003 client is not the 2026 one with older data. It is the build that shipped then, and two
things about it differ from everything ffxi-native supported before:

- **Its DLLs are packed with ASProtect**, not the later POL1 packer. ffxi-native's
  `tools/aspack_unpack.py` runs the protector's stub under an emulator (never natively) to the
  original entry point, recovers the relocations by running it at two bases, and rebuilds the import
  table the protector wipes. The game host then maps that unpacked image, made on your machine, in
  place of the retail DLL.
- **It speaks the 2003 protocol.** Packet layouts, the lobby and sign-in all predate what
  LandSandBoat implements. Translating them is the main open work (below).

## Rules

- **No Square Enix bytes in this repository, ever**: no DLLs, no DAT files, no unpacked images, no
  generated C. Everything derived from the game is made on the player's machine from their own
  install. `.gitignore` enforces the obvious paths; the rule applies everywhere.
- Committed: tools, scripts, server modules, and per-build metadata (addresses and shapes only),
  which lives in ffxi-native.

## Status

| step | state |
| --- | --- |
| identify the 2003 build (`2003-09-05`, client version `30030905_0`) | done |
| unpack ASProtect: entry points, relocations, imports | done |
| discovery pass (Ghidra) for FFXi.dll | done, clean |
| discovery pass for FFXiMain.dll | done: 16,512 functions, 623 switches, gate clean |
| translate both DLLs to C | done (its SIMD paths, like 2026's, stay unused: the runtime reports a CPU without MMX/SSE/3DNow!) |
| game host maps an unpacked image (no POL1) | written; boot test in progress |
| server: `era2003` module (zones, accounts, settings) | done, untested in play |
| the 2003 sign-in (PlayOnline of 2003) | to do |
| the 2003 packet protocol, both ways | to do |
| the launcher | to do |

## The 2003 install

Point it at a `FINAL FANTASY XI` folder holding the September 2003 build (`FFXiMain.dll` with
SHA-256 `8193cd38…55f7cb`): `ROM` and `ROM2` (base game and Rise of Zilart), the `sound` folders,
and `FTABLE.DAT` / `VTABLE.DAT`. Nothing in it is ever changed.
