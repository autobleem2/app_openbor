# app_openbor - developer context

**OpenBOR** packaged as **one AutoBleem App**, one zip per platform (`dist/openbor-<key>-<version>.zip`, laid out as
`Apps/openbor/`), in the multi-platform App format (the launcher's `docs/app-format-plan.md`). Store id
`app/openbor` - the RetroBoot App's folder and id, so the Store updates it in place on psc.

Started 2026-09-25, the seventh third-party App port (autobleem-main `docs/decisions.md`, "Third-party App
ports" - the rules; `app_opentyrian`'s CLAUDE.md is the template). The 2019 PlayStation Classic port is
`screemerpl/openbor-psc` (archived; its menu art is the one thing taken from it).

## The owner's decisions for this port (2026-09-25)

- **Upstream**: `DCurrent/openbor` at tag **`v7533`** (`5c826144`, 2024-01-01), the package version `7533-1`
  (`VERSION`). Later builds (master, the 4.0 line past 7533) build **64-bit only** - the console, the 32-bit Pi and
  the PC stick are 32-bit - so 7533 is the last build every target can run.
- **Branding** (Amiberry and OpenBOR keep ours): the 2019 port's **menu background** (`resources/branding/
  AutoBleem_Menu_480x272.png`, kept as it was) and a **clean start-up logo** - OpenBOR's own logo with the
  AutoBleem mark cut from that menu art in its corner. The 2019 logo is not used: it was a collage of commercial
  fighting-game characters. The credits roll gains a "Playstation Classic - Screemer, KMFDManic" line.
- **The 2019 pad layout**: Cross/Circle/Square/Triangle attack 1-4, L1 jump, R1 special, Start, Select
  screenshot, L2 the menu (Esc).
- **Media**: WebM video (VP8) and Vorbis music both supported.
- **Games**: "just 1-2" to ship - **still open**: none named yet. Almost every OpenBOR game is a fan game over
  commercial characters; one with clean rights is what to look for. Until then the package ships an empty
  `Paks/` and the readme says where games come from.

## Layout

| path | what |
|---|---|
| `upstream/openbor` | the pinned engine (submodule, `v7533`) |
| `upstream/{zlib,libpng,ogg,vorbis,libvpx}` | the codecs, pinned (zlib 1.3.1, libpng 1.6.58, libogg 1.3.6, libvorbis 1.3.7, libvpx 1.15.2), built static per target and linked in |
| `upstream/SDL2_gfx` | only `SDL2_framerate.c` is used (OpenBOR's frame limiter), compiled into the program |
| `patches/openbor/0001-psc-pad-defaults.patch` | `control_pad_default_keys()` in `sdl/control.c`, called by `clearbuttons()` for players 1 and 2: on Linux the numbering of the virtual pad's **PlayStation Classic layout** (Triangle 0, Circle 1, Cross 2, Square 3, L2 4, R2 5, L1 6, R1 7, Select 8, Start 9, the D-pad on axes 0/1); on Windows (`_WIN32`) through `SDL_GameControllerGetBindForButton/Axis`, so any XInput pad gets the same layout (L2 is the left trigger, an axis). Also: `open_joystick` names a pad by index with a NULL guard. |
| `patches/openbor/0002-autobleem-branding.patch` | the wide (480x272) logo and menu from `resources/autobleem_{logo,menu}_480x272.png.h`, the credits line |
| `patches/openbor/0003-full-screen-by-default.patch` | full screen and the wide menu from the start (`savedata.fullscreen`, the menu's `isWide`/`isFull`) |
| `patches/openbor/0004-pad-defaults-once-the-pads-are-open.patch` | `apply_controls()` (which runs after `control_init()` has opened the pads) gives a player whose key set names no pad input at all the pad defaults (0001), and binds Esc to the set's own Esc key (L2) when it is a pad input - upstream binds it to the keyboard's Escape only. Without it the pad did nothing (found on the console, 2026-09-25): the game list's `loadsettings()` -> `clearbuttons()` ran before the pads were open, so 0001 found none and the keyboard defaults stayed (and a `Saves/default.cfg` written then kept them). From `7533-2` |
| `patches/openbor/0005-playstation-button-names.patch` | **Linux only**: the names on screen (the game list's hints, the control options) are the PlayStation Classic pad's for the virtual pad's console layout (10 buttons, 2 axes) - `P1 ^`/`O`/`X`/`[]`, `L2`/`R2`/`L1`/`R1`, `Select`/`Start`, and `Left`/`Right`/`Up`/`Down` for the D-pad's axes - as the 2019 port (`screemerpl/openbor-psc`, its `PSCButtonNames`) had them; upstream's were `P1 Button 3`, `P1 Axis 1 -`. From `7533-3` |
| `resources/build/CMakeLists.txt` | our build of the engine (copied into the build's `engine/`): upstream's Makefile SDL source list (SDL + SDL_IO + GFX + VORBIS + WEBM + PTHREAD, **no OpenGL** - `sdl/opengl.h` stubs it), `-DLINUX`/`-DWIN`, `SDL=1`, every library by path; Windows adds `resources/OpenBOR.rc` (icon, version block) |
| `resources/app/` | `app.ini` (`Exec=bin/{key}/OpenBOR`, no `Args`, no `Lib` - SDL2 is the launcher's or the system's), `pad.ini` (`virtual = psc`), `readme.txt`, `icon.png`, `Paks/` (games to ship go here) |
| `resources/branding/` | the menu art (2019) and the logo `tools/make_branding.py --art` draws |
| `ci/build.sh` | `native|psc|rpi|rpi64|pcusb|win|all`: per target the codecs into `build_<key>/deps` (kept while `deps/.stamp` - the submodule commits, compiler, flags - matches; libvpx is most of a clean build), then a copy of the engine, the patches, a `version.h` written in place of upstream's git-reading `version.sh`, `tools/make_branding.py <engine>` (embeds the two PNGs as makeheader-style headers, stdlib only - the image has no Pillow), CMake. libvpx: `armv7-linux-gcc` (psc, rpi), `arm64-linux-gcc` (rpi64), `generic-gnu` on x86 (the image has no nasm/yasm), VP8 decoder only. The package carries `LICENSE-openbor.txt` and `licences/` (the codecs' notices). |
| `tools/store_item.py`, `tools/check_psc_binary.sh`, `tools/check_needed.sh`, `tools/zip_app.py` | as in the other ports (`check_needed.sh` also allows `psapi.dll`); `zip_app.py` keeps the empty `Paks/`/`Saves/` folders |

## Things to know

- **Where OpenBOR keeps things**: its working directory - the App folder (the launcher starts an App there):
  `Paks/`, `Saves/` (settings per game, `default.cfg`), `Logs/`, `ScreenShots/`, created on first start. With
  one argument that names an existing `.pak` it skips the menu and starts that game.
- **Leaving**: Reset on the console, the Start+Select hold on Linux; on Windows L2 (the menu), then Quit.
- **Windows**: ran on the dev PC on 2026-09-25 with SDL2.dll on PATH - the menu came up full screen, title
  "OpenBOR" (no paks: "No Mods In Paks Folder!").
- **Build on the server**: sync with MSYS2's rsync (excluding `/build_*`, `/dist`), then
  `docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all`;
  remove `build_*`/`dist` there afterwards.
- **Releases**: a `v<version>` tag (`v7533-1`) builds a stable GitHub release with the five zips (in the release
  image, `autobleem-build:latest`); `master` follows the released commit. The Store gets it by hand:
  `gh release download <tag>`, `tools/store_item.py` per zip, then autobleem-repo's
  `repo_publish.sh store <key> dist/store/<key>/*`.
- **Not yet run**: on a console, a Pi or the PC stick (the tester checklist, section 12).
