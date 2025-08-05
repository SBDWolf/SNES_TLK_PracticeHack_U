
; Hijack NMI to handle time control
org $C09E16
    JML NMITimeControl


; Hijack NMI to inc/draw timer
org $C09E6D
	JSL TimerHijack
	NOP


; Hijack checkpoint loading to mark TimeAttack_DNR
org $C08849
    JSL LoadFromCheckpointHijack


; Hijack fade in complete to draw previous time
org $C0A2FE
    JML RedrawAndResetTimer
    NOP

; Hijack level complete to stop timer and run TimeAttack
; Pridelands covered by cutscene skip hijack
org $C0D1CB ; Roar at Monkeys, STA !LK_Loading_Trigger
    JSL LevelCompleteHijack_RoarMonkeys

org $C48580 ; Elephant Graveyard, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C0B63B ; The Stampede, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C1A635 ; Simba's Exile, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C04A52 ; Hakuna Matata, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C1AADC ; Simba's Destiny, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C6439E ; Be Prepared, LDA #$0001 : STA $A692
    JSL LevelCompleteHijack
    NOP #2

org $C0D448 ; Simba's Return, adds STA $0A44 between
    JSL LevelCompleteHijack_SimbasReturn
    RTL
    NOP

org $C65DC9 ; Pride Rock, STA $A6C2 <
    JSL LevelCompleteHijack_PrideRock
    NOP #2

; Hijack Simba death to correct timer
org $C00222
    JML DeathTimerHijack

; Hijack screen fade outs in Simba's Return to prevent timer resets
org $C38994
    JML IgnoreMinorTransition
IgnoreMinorTransition_return:


%startfree(F1)

NMITimeControl:
; The idle routine refuses to return until its flag has been flipped in NMI
; By short circuiting NMI, we can delay gameplay processing by a frame
{
    ; overwritten code
    LDX #$00 : PHX : PLB

    LDA !ram_TimeControl_mode : BNE .timeControl
    JML $C09E1A ; return to NMI

  .timeControl
    ; Modes: 0001 = slowdown, 0002 = loadstate timer, 0010 = loadstate waits for input
    ;        FFFE = frame advance, FFFF = pause
    CMP #$FFFF : BEQ .pause
    LDA !ram_TimeControl_mode : BMI .frameAdvance
    CMP #$0001 : BNE .loadstateFreeze
    LDA !ram_TimeControl_timer : BNE .slowdown

  .reset
    ; reset countdown and restore inputs
    LDA !ram_TimeControl_frames : STA !ram_TimeControl_timer
    LDA !ram_TimeControl_P1 : STA !LK_Controller_Current : STA !LK_Controller_New
    LDA !ram_TimeControl_P2 : STA !LK_Controller_P2Current
    JML $C09E1A ; return to NMI

  .pause
    LDA !LK_Controller_Current : STA !ram_TimeControl_P1
    LDA !LK_Controller_P2Current : STA !ram_TimeControl_P2
    JSL ReadControllerInputs_long
    %ai16()
    JML $C09EBF ; skip NMI

  .frameAdvance
    LDA #$FFFF : STA !ram_TimeControl_mode
    JML $C09E1A ; return to NMI

  .slowdown
    LDA !ram_TimeControl_frames : BEQ .pause
    LDA !ram_TimeControl_timer : DEC : STA !ram_TimeControl_timer
    JSL ReadControllerInputs_long
    %ai16()
    JML $C09EBF ; skip NMI

  .loadstateFreeze
    LDA !ram_TimeControl_mode : CMP #$0010 : BEQ .wait4Input
    ; countdown delay timer
    LDA !ram_TimeControl_timer : BEQ .unfreeze
    DEC : STA !ram_TimeControl_timer
    JSL ReadControllerInputs_long
    %ai16()
    JML $C09EBF ; skip NMI

  .wait4Input
    LDA !LK_Controller_New : BNE .unfreeze
    JSL ReadControllerInputs_long
    %ai16()
    JML $C09EBF ; skip NMI

  .unfreeze
    %a8()
    LDA !sram_loadstate_redraw : BNE .restoreIRQ
    ; restore screen brightness
    LDA !ram_loadstate_2100 : STA !LK_2100_Brightness
    BRA .end

  .restoreIRQ
    LDA !ram_loadstate_4200 : STA !LK_4200_NMIEnable

  .end
    %a16()
    LDA #$0000 : STA !ram_TimeControl_mode
    STA !ram_TimeControl_frames : STA !ram_TimeControl_timer
    JML $C09E1A ; return to NMI
}


RedrawAndResetTimer:
{
    PHP : %ai16()

    ; don't reset for minor transitions on Simba's Return
    LDA !ram_timer_ignore : BEQ +
    LDA !LK_Current_Level : CMP #$0008 : BEQ .return

    ; clear the flag if not Simba's Return
    LDA #$0000 : STA !ram_timer_ignore

    ; restore recorded time
+   LDA !ram_previous_frames : STA !ram_timer_frames
    LDA !ram_previous_minutes : STA !ram_timer_minutes

    JSL UpdateHUD

    ; check if Pridelands cutscene
    LDA !ram_timer_capped : BMI .cutscene

    ; reset timer
    LDA #$0000 : STA !ram_timer_capped : STA !ram_timer_recorded
    STA !ram_timer_frames : STA !ram_timer_seconds ; minutess included
    BRA .return

  .cutscene
    ; wait until next level to reset times
    LDA #$0001 : STA !ram_timer_capped

  .return
    ; overwritten code
    LDA #$0F00 : STA !LK_FadeInOut_Flag
    XBA ; fixes screen flash at start of level

    PLP
    JML $C0A313 ; overwritten BRA
}


TimerHijack:
{
    %a8()
    ; don't count time if we're fading in/out
    LDA !LK_FadeInOut_Flag : BIT #$01 : BEQ .update_timer
    BIT #$10 : BEQ .done
    BRL UpdateHUD

  .update_timer
    ; don't count time if paused or over 10 minutes
    LDA !LK_Pause_Flag : BNE .done
    LDA.w !ram_timer_capped : BNE .done

    SED ; set decimal mode
    ; increment frame count by 1, rollover at 60
    LDA.w !ram_timer_frames : CLC : ADC #$01 : STA.w !ram_timer_frames
    CMP #$60 : BCC .done
    LDA #$00 : STA.w !ram_timer_frames

    LDA.w !ram_timer_seconds : CLC : ADC #$01 : STA.w !ram_timer_seconds
    CMP #$60 : BCC .done
    LDA #$00 : STA.w !ram_timer_seconds

    LDA.w !ram_timer_minutes : CLC : ADC #$01 : STA.w !ram_timer_minutes
    CMP #$10 : BCC .done

    ; minutes count is 10, stop updating the timer
    LDA #$09 : STA.w !ram_timer_minutes
    LDA #$59
    STA.w !ram_timer_seconds : STA.w !ram_timer_frames
    STA.w !ram_timer_capped

  .done
    CLD ; clear decimal mode
    ; don't overwrite the menu tilemap in VRAM
    LDA.w !ram_menu_active : BNE .skip

    ; update HUD if Select (or X in level 10) is newly pressed
    LDA !LK_Current_Level : CMP #$09 : BEQ .finalLevel
    ; check high byte for Select
    LDA !LK_Controller_New+1 : BIT #$20 : BNE UpdateHUD

  .skip
    %a16()
    INC $E5 ; overwritten code
    LDA $0A89
    RTL

  .finalLevel
    ; check low byte for Select or X
    LDA !LK_Controller_New+1 : BIT #$20 : BNE UpdateHUD
    LDA !LK_Controller_New : BIT #$40 : BEQ .skip

    ; check Simba pointer for final throw
    %a16()
    LDA $7EB243 : CMP #$78E9 : BNE .skip
    LDA !ram_timer_recorded : BNE .skip

    ; save timer for later
    LDA.w !ram_timer_frames : STA.w !ram_previous_frames ; includes seconds
    LDA.w !ram_timer_minutes : STA.w !ram_previous_minutes

    ; fall through to UpdateHUD
}

UpdateHUD:
{
    ; these addresses contain current OAM information,
    ; such as current X and Y coordinate,
    ; current sprite from the tile list, etc.
    %a16()
    LDA #$C808 : STA $0300
    LDA #$31E0 : STA $0302
    LDA #$C820 : STA $0304
    LDA #$31E2 : STA $0306
    LDA #$C832 : STA $0308
    LDA #$31E4 : STA $030A
    LDA #$C84A : STA $030C
    LDA #$31E6 : STA $030E
    LDA #$C85C : STA $0310
    LDA #$31CE : STA $0312

    ; memorize the current sprite to manipulate to display one number
    ; then load the drawing routine 5 times (one for each digit)
    ; minutes digit
    LDA #$0078 : STA.w !ram_sprite_tile
    JSL $C001B5

    ; 1st seconds digit
    LDA #$0079 : STA.w !ram_sprite_tile
    JSL $C001B5

    ; 2nd seconds digit
    LDA #$007A : STA.w !ram_sprite_tile
    JSL $C001B5

    ; 1st frames digit
    LDA #$007B : STA.w !ram_sprite_tile
    JSL $C001B5

    ; 2nd frames digit
    LDA #$0077 : STA.w !ram_sprite_tile
    JSL $C001B5

    ; returning to hijacked routine
    INC $E5 ; overwritten code
    LDA $0A89
    RTL
}

pushpc

; edit Simba head/lives check
org $C001C9
Begin_Edits_for_Timer:
{
    BNE .done
    LDA !LK_Title_Screen : CMP #$0068 : BEQ .done
    LDA !LK_Exile_Cutscene : BIT #$0080 : BNE .done
    JSL timer_load
    XBA : LSR : ADC #$FA33 : STA $202B
    LDA #$200C : STA $85
    LDA #$7E20 : STA $86
    LDA.w !ram_sprite_tile : STA $93
    JSR $A84B

  .done
    PLD : PLB : PLP
    RTL
End_Edits_for_Timer:
}

warnpc $C00201 ; don't overwrite the next routine
pullpc

timer_load:
{
; this gets called from the edited routine at $C001B5
; it determines which byte of the timer to select based on the value previously stored at !ram_sprite_tile
; and then performs some calculations to get just one digit from a byte
    LDA !ram_sprite_tile : BIT #$0001 : BNE .odd_fork

    BIT #$0002 : BNE .seconds_2
    ; minutes digit
    LDA !ram_timer_minutes
    RTL

    ; 2nd seconds digit
  .seconds_2
    LDA !ram_timer_seconds : AND #$000F
    RTL

  .odd_fork
    BIT #$0008 : BEQ .frames_2
    BIT #$0002 : BNE .frames_1
    ; 1st seconds digit
    LDA !ram_timer_seconds : AND #$00F0 : LSR #4
    RTL

    ; 1st frames digit
  .frames_1
    LDA !ram_timer_frames : AND #$00F0 : LSR #4
    RTL
    
    ; 2nd frames digit
  .frames_2
    LDA !ram_timer_frames : AND #$000F
    RTL
}

TimeAttack:
{
    PHP : %ai16()
    ; Do not track if checkpoint used
    LDA !ram_TimeAttack_DoNotRecord : BNE .done

    ; check for non-tracked levels (bonuses, title, Kill Him)
    LDA !LK_Current_Level : CMP #$000A : BPL .done

    ; use current level * 3 + difficulty * 20 as index
    ASL : ADC !LK_Current_Level : STA !ram_temp
    LDA !LK_Options_Difficulty : ASL #5
    CLC : ADC !ram_temp : TAX

    ; check if PB
    %a8()
    LDA !sram_TimeAttack_minutes,X : CMP #$10 : BPL .newPB
    CMP !ram_timer_minutes : BEQ +
    BPL .newPB
+   LDA !sram_TimeAttack_seconds,X : CMP !ram_timer_seconds : BEQ +
    BPL .newPB
+   LDA !sram_TimeAttack_frames,X : CMP !ram_timer_frames : BEQ .done ; tied PB
    BMI .done

  .newPB
    LDA !ram_timer_frames : STA !sram_TimeAttack_frames,X
    %a16()
    LDA !ram_timer_seconds : STA !sram_TimeAttack_seconds,X ; also mins
    ; do stuff here to tell the player they PB'd

  .done
    PLP
    RTL
}

LoadFromCheckpointHijack:
{
    ; don't track PBs from checkpoints
    STA !ram_TimeAttack_DoNotRecord
    ; overwritten code
    LDA !LK_Simba_Health_Max
    RTL
}

LevelCompleteHijack:
{
    PHX : PHY : PHP

    LDA #$0001
    STA.w !LK_Loading_Trigger ; overwritten code

  .common
    ; store timer to be redrawn later
    LDA !ram_timer_frames : STA !ram_previous_frames
    LDA !ram_timer_minutes : STA !ram_previous_minutes

  .scar
    ; Scar's finish time was already stored in TimerHijack
    JSL TimeAttack

    ; save timer to be redrawn later, includes seconds
    LDA !ram_timer_frames : STA !ram_previous_frames
    LDA !ram_timer_minutes : STA !ram_previous_minutes
    LDA #$0001
    STA !ram_timer_recorded : STA !ram_timer_capped

    PLP : PLY : PLX
    RTL
}

LevelCompleteHijack_RoarMonkeys:
{
    PHX : PHY : PHP

    STA !LK_Loading_Trigger ; overwritten code

    JMP LevelCompleteHijack_common
}

LevelCompleteHijack_SimbasReturn:
{
    PHX : PHY : PHP

    ; overwritten code
    LDA #$0001
    STA $0A44 : STA.w !LK_Loading_Trigger

    JMP LevelCompleteHijack_common
}

LevelCompleteHijack_PrideRock:
{
    PHX : PHY : PHP

    LDA #$0001 : STA $A6C2 ; overwritten code

    ; this code runs every frame, only run the timer stuff once
    LDA !ram_timer_recorded : BNE .abort
    JMP LevelCompleteHijack_scar

  .abort
    PLP : PLY : PLX
    RTL
}

DeathTimerHijack:
{
    ; save timer to be redrawn later, includes seconds
    LDA !ram_timer_frames : STA !ram_previous_frames
    LDA !ram_timer_minutes : STA !ram_previous_minutes
    LDA #$0001
    STA !ram_timer_recorded : STA !ram_timer_capped
    LDA #$0000 : STA !ram_timer_ignore

    JML $C089B7 ; overwritten code
}

IgnoreMinorTransition:
{
    %a8()
    LDA #$FF : STA !ram_timer_ignore
    JML IgnoreMinorTransition_return
}
%endfree(F1)
