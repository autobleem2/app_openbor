OpenBOR
=======

OpenBOR is the open-source continuation of Senile Team's Beats of Rage: an engine for side-scrolling beat 'em
ups, and hundreds of free games ("mods") made with it by its community. Each game is one .pak file.


Adding games
------------

Copy a game's .pak file into the Paks folder of this App (Apps/openbor/Paks on the stick). OpenBOR lists every
.pak there when it starts; pick one with the D-Pad and press Start.

Games are found at ChronoCrash (https://www.chronocrash.com), OpenBOR's home. Most are fan games built on
characters of commercial series, so none of those is included - which ones you copy is up to you.
Games made for OpenBOR 3.0 and 4.0 builds up to 7533 run; games that need a newer (64-bit only) build do not.


Controls
--------

D-Pad / left stick   Move
Cross                Attack
Circle               Attack 2
Square               Attack 3
Triangle             Attack 4
L1                   Jump
R1                   Special
Start                Start, pause
Select               Screenshot (into ScreenShots/)
L2                   Menu (Esc) - settings, and Quit

Every game can be re-bound in its own Options > Control Options.

To leave the game: press Reset on the console, or hold Start + Select (the console, the Pi and the PC stick).
On Windows: L2 for the menu, then Quit.

The settings, the saved games, the logs and the screenshots are kept in this folder.


Credits
-------

OpenBOR: the OpenBOR Team (Damon Caskey, Plombo, SX, Utunnels, White Dragon, Kratus and many more) -
https://github.com/DCurrent/openbor (BSD-3-Clause, see LICENSE-openbor.txt). Beats of Rage: Roel van
Mastbergen and Senile Team, 2003.
PlayStation Classic port (2019): Screemer, KMFDManic. AutoBleem package: the AutoBleem team.
Built in: zlib, libpng, libogg, libvorbis, libvpx (WebM video), SDL2_gfx's frame-rate limiter.
