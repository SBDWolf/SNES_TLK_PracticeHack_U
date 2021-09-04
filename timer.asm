org every_frame
	; check if loading a level, if so reset timer to 0
	
	LDA #$0000
	SEP #$20
	LDA load_state
	CMP #$00
	REP #$20
	BNE checks
	STA timer_frames
	STA timer_minutes
	STA $7FFEC4
	STA tile_load_info
	BRA done
	
	;check various play states
	checks:
	LDA fade_in_state
	BIT #$0001
	BNE fade_in
	LDA pause_flag
	BIT #$0001
	BNE done
	LDA timer_cap_flag
	BIT #$0001
	BNE done
	BRA update_timer
	
	fade_in:
	BIT #$0010
	BNE update_hud
	BRA done
	
	; enable decimal mode, increment frame count by 1
	update_timer:
	SED
	SEP #$28
	LDA timer_frames
	CLC
	ADC #$01
	STA timer_frames
	CMP #$60
	BCC done
	
	; if frame count is 60, reset to 0 and increment seconds
	LDA #$00
	STA timer_frames
	LDA timer_seconds
	CLC
	ADC #$01
	STA timer_seconds
	CMP #$60
	BCC done
	
	; if second count is 60, reset to 0 and increment minutes
	LDA #$00
	STA timer_seconds
	LDA timer_minutes
	CLC
	ADC #$01
	STA timer_minutes
	CMP #$10
	BCC done
	
	; if minutes count is 10, stop updating the timer
	LDA #$09
	STA timer_minutes
	LDA #$59
	STA timer_seconds
	LDA #$59
	STA timer_frames
	LDA #$01
	STA timer_cap_flag
	
	
	;prepare to return to hijacked routine, but check if select has been pressed first and update the hud if so
	done:
	CLD
	REP #$28
	LDA button_pressed_high_byte
	BIT #$0020
	BNE update_hud
	INC $E5
	LDA $0A89
	RTL
	
	update_hud:
	
	
	;these addresses contain current OAM information,
	;such as current X and Y coordinate,
	;current sprite from the tile list, etc.
	REP #$28
	LDA #$C808
	STA $7E0300
	LDA #$31E0
	STA $7E0302
	LDA #$C820
	STA $7E0304
	LDA #$31E2
	STA $7E0306
	LDA #$C832
	STA $7E0308
	LDA #$31E4
	STA $7E030A
	LDA #$C84A
	STA $7E030C
	LDA #$31E6
	STA $7E030E
	LDA #$C85C
	STA $7E0310
	LDA #$31CE
	STA $7E0312
	
	;garbage code ahead

	;memorize the current sprite to manipulate to display one number, then load the drawing routine 5 times (one for each digit)
	;minutes digit
	REP #$28
	LDA #$0078
	STA tile_load_info
	;I have no idea if manipulating $200A is actually necessary tbh
	LDA #$FFFF
	STA $7E200A
	JSL $C001B5
	
	;first seconds digit
	LDA #$0079
	STA tile_load_info
	LDA #$FFFF
	STA $7E200A
	JSL $C001B5
	
	;second seconds digit
	LDA #$007A
	STA tile_load_info
	LDA #$FFFF
	STA $7E200A
	JSL $C001B5
	
	;first frames digit
	LDA #$007B
	STA tile_load_info
	LDA #$FFFF
	STA $7E200A
	JSL $C001B5
	
	;second frames digit
	LDA #$0077
	STA tile_load_info
	LDA #$FFFF
	STA $7E200A
	JSL $C001B5

	;again not sure if this is necessary
	LDA #$0000
	STA $7E200A
	
	;returning to hijacked routine
	INC $E5
	LDA $0A89
	RTL
	
	timer_load:

	;this gets called from the edited routine at $C001B5
	;it determines which byte of the timer to select based on the value previously stored at tile_load_info
	;and then performs some calculations to get just one digit from a byte
	LDA tile_load_info
	BIT #$0001
	BNE odd_fork
	
	BIT #$0002
	BNE seconds_2
	
	;minutes digit
	minutes:
	LDA timer_minutes
	RTL
	
	;second seconds digit
	seconds_2:
	LDA timer_seconds
	AND #$000F
	RTL
	
	odd_fork:
	BIT #$0008
	BEQ frames_2
	
	BIT #$0002
	BNE frames_1
	
	;first seconds digit
	seconds_1:
	LDA timer_seconds
	AND #$00F0
	LSR
	LSR
	LSR
	LSR
	RTL
	
	;first frames digit
	frames_1:
	LDA timer_frames
	AND #$00F0
	LSR
	LSR
	LSR
	LSR
	RTL
	
	;second frames digit
	frames_2:
	LDA timer_frames
	AND #$000F
	RTL
	
	