# SNES_TLK_TimerHack_U
Timer Hack for the SNES game The Lion King

To be assembled using Asar, run "asar.exe --fix-checksum=off main.asm {ROM name}" through the command prompt.

Features:
- Level timer. I unfortunately couldn't get it to display and update every frame without risk of crashing the game, so it instead displays the final level time at the end of a level. It displays on the bottom left of the screen in "m ss ff" format (m = minutes, s = seconds, f = frames)
- You can press select on the controller to display what the timer currently reads at any moment.
- Inside level 10 only, pressing X also displays the current timer value on the screen. This makes timing the end point of the level a lot more efficient.
- Removes game overs.

Known issues:
- It doesn't seem to behave consistently after dying and restarting from a checkpoint. On certain checkpoints it'll reset the timer, on others it won't.
- Small graphical glitches elsewhere (like on title screen, sometimes)
- In level 9 the timer automatically displays as you enter every door. Not necessarily an issue, but an unintended side-effect.
