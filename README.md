# app_openbor

[OpenBOR](https://github.com/DCurrent/openbor), the open-source Beats of Rage engine, packaged as an
[AutoBleem](https://github.com/autobleem2/autobleem) App for the PlayStation Classic, the Raspberry Pi, the
AutoBleem PC stick and Windows - with the AutoBleem menu art of the 2019 PlayStation Classic port.

Install it from the AutoBleem Store, then copy games (`.pak` files) into `Apps/openbor/Paks`. The upstream source
and the codecs are pinned submodules; this repository holds only the build (`ci/build.sh`, run in the
[autobleem-build](https://github.com/autobleem2/autobleem-build) image), three patches (the PlayStation Classic
pad defaults, the branding, full screen) and the App's files.

```
git clone --recurse-submodules https://github.com/autobleem2/app_openbor
ci/build.sh all    # inside ghcr.io/autobleem2/autobleem-build
```

Controls (PlayStation Classic pad): D-pad move, Cross/Circle/Square/Triangle attack 1-4, L1 jump, R1 special,
Start start/pause, Select screenshot, L2 the menu. Press Reset on the console or hold Start + Select to leave.

Licence: the build, patches and tools GPL-3.0-or-later; OpenBOR BSD-3-Clause; the bundled codecs their own
(zlib, libpng, BSD) - see `LICENSE`.
