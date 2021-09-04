# SNES_TLK_TimerHack_U
Timer Hack for the SNES game The Lion King

To be assembled using Asar, run "asar.exe --fix-checksum=off main.asm {ROM name}" through the command prompt.

Features:
- Level timer. I unfortunately couldn't get it to display and update every frame without risk of crashing the game, so it instead displays the final level time at the end of a level.
- You can press select on the controller to display what the timer currently reads at any moment.
- Removes game overs.

Known issues:
- It doesn't seem to behave consistently after dying and restarting from a checkpoint. On certain checkpoints it'll reset the timer, on others it won't.
- Small graphical glitches elsewhere (like on title screen, sometimes)
