# The Lion King Practice Hack (SNES)
 This hack is intended to help speedrunners practice the game in the most convenient ways possible.


## How to get it:
 Check the \releases\ directory for pre-made IPS patch files. Further instructions are available in the `README.md` file there.


## How to build/apply changes:

### Building IPS patches:
 Building patches requires Python 3.0+ installed, but does not require a ROM to produce the IPS patches.

1. Download and install Python 3+ from https://python.org. Windows users will need to set the PATH environmental variable to point to their Python installation folder.
2. Run `build_ips.bat` to create IPS patch files.
3. Locate the patch files in the \build\ folder.

### Building a patched ROM:

1. Rename your unheadered TLK rom to `LionKing.sfc` and place it in the \build\ folder.
2. Run `build_rom.bat` to generate a patched practice rom in the \build\ folder.


## Features included:

- Pause menu (Start+Select by default) to access practice features anytime during gameplay
- Ability to save and reload instantly during gameplay (on supported platforms)
- Level timer displayed on the HUD at level completion, when Select is pressed, or when the final attack on Scar is executed
- Tracking for fastest level completion times across each difficulty
- Customizable controller shortcuts
- Shortcuts to pause time, frame advance, and/or play in slow motion
- Simba menu to set values such as health, roar, invulnerability, and more
- Level select menu lets you load any level and edit checkpoint positions freely
- Memory editor tools
- Option to show CPU usage by darkening the screen during idle time
- Option to skip directly to the title screen on boot/reset
- Options to skip death and story cutscenes
- Option to automatically load a savestate upon death
- Options to load, preserve, or cycle the RNG when loading savestates
- Access to the game's own options within the practice menu

## Special thanks:

- The practice menu, controller shortcuts, and savestates are forked from Super Metroid's practice hack found at [github.com/tewtal/sm_practice_hack](https://github.com/tewtal/sm_practice_hack). Modifications were made to fit Lion King.


## Known Issues:
 The following issues are known and will require additional disassembly work to fix. Submit a pull request if you have the assembly skills to fix them.

- Savestates are not capable of adjusting music for certain levels. This may lead to game crashes due to a desync between the main and audio processors. The first Hyena fight, as well as Pride Rock, are known to cause issues. Avoid music changes when using savestates in these areas.
