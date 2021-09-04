org frame_hijack
	JSL every_frame ; this runs in VBlank, right before the current frame counter at $E5 gets incremented
	NOP