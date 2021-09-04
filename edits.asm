@include

; skip game over check
org game_over_check
	NOP
	NOP
	
;don't update lives digit after getting a 1up
org lives_inc_edit
	NOP
	NOP
	NOP
	NOP
	
	
	
org lives_routine_edit
	LDA title_screen_check
	CMP #$0068
	BEQ $29
	LDA exile_cutscene_check
	BIT #$0080
	BNE $20
	JSL timer_load
	NOP
	XBA
	LSR
	ADC #$FA33
	STA $202B
	LDA #$200C
	STA $85
	LDA #$7E20
	STA $86
	LDA $7FFEC6
	STA $93
	JSR $A84B
	PLD
	PLB
	PLP
	RTL

; this is where Simba's head and lives count are initialized from in ROM. I was going to edit this initially but I decided to update the OAM data on the fly instead
;org hud_init
;db $08, $C8, $E0, $31, $20, $C8, $E2, $31, $32, $C8, $E4, $31, $4A, $C8, $E6, $31, $5C, $C8, $CE, $31, $08, $C8, $E0, $31, $20, $C8, $E2, $31, $32, $C8, $E4, $31, $4A, $C8, $E6, $31, $5C, $C8, $CE, $31
	