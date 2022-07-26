

org $C0A07C
    JMP ReadControllerInputs

org $C0FF00
print pc, " ReadControllerInputs start"
ReadControllerInputs_long:
{
    JSR ReadControllerInputs_PHP

  .return
    RTL
}

ReadControllerInputs_PHP:
    PHP
    ; fallthrough

ReadControllerInputs:
; This is the vanilla routine with new inputs stored at !LK_Controller_New
; and controller shortcuts checked before returning
{
    %a8()
    LDA $4218 : STA.w !LK_Controller_Filtered
    ; determine new inputs (p1 low)
    EOR.w !LK_Controller_Current : AND.w !LK_Controller_Filtered : STA !LK_Controller_New

    LDA $4219 : STA.w !LK_Controller_Filtered+1
    ; determine new inputs (p1 high)
    EOR.w !LK_Controller_Current+1 : AND.w !LK_Controller_Filtered+1 : STA.w !LK_Controller_New+1

    LDA $421B : STA.w !LK_Controller_P2Filtered+1
    ; determine new inputs (p2 high)
    EOR.w !LK_Controller_P2Current+1 : AND.w !LK_Controller_P2Filtered+1 : STA.w !LK_Controller_P2New+1

    %a16()
    LDA.w !LK_Controller_Filtered : AND #$000F : BEQ +
    STZ.w !LK_Controller_Filtered
+   LDA !LK_Options_Controller : BNE +
    LDA $005E : STA $0060
    BRA .done
+   DEC : ASL : TAX
    LDA #$C080 : TRB $0060
    LDA $005E : BPL +
    LDA $C3BEE2,X : TSB $60
+   LDA $005E : AND #$0080 : BEQ +
    LDA $C3BED8,X : TSB $0060
+   LDA $005E : AND #$4000 : BEQ .done
    LDA $C3BEEC,X : TSB $0060

  .done
    LDA.w !LK_Controller_Current : AND $0060 : EOR #$FFFF : STA $001B
    LDA.w !LK_Controller_Filtered : STA.w !LK_Controller_Current
    AND $001B : STA.w !LK_Controller_Filtered
    LDA.w !LK_Controller_P2Filtered : STA.w !LK_Controller_P2Current

    JSL ControllerShortcuts

    PLP
    RTS
}
print pc, " ReadControllerInputs end"
warnpc $C0FFB0 ; game header


org $F20000
print pc, " ControllerShortcuts start"
ControllerShortcuts:
{
    ; no shortcuts allowed in menu
    LDA !ram_menu_active : BEQ .p2Inputs
    RTL

  .p2Inputs
    LDA !LK_Controller_P2New : AND #$0F00 : BEQ .newInputs
    BRL .timeControl

  .newInputs
    LDA !LK_Controller_New : BNE +
    RTL

+   LDA !LK_Controller_Current : AND !sram_ctrl_save_state : CMP !sram_ctrl_save_state : BNE +
    AND !LK_Controller_New : BEQ +
    BRL .savestate

+   LDA !LK_Controller_Current : AND !sram_ctrl_load_state : CMP !sram_ctrl_load_state : BNE +
    AND !LK_Controller_New : BEQ +
    BRA .loadstate

+   LDA !LK_Controller_Current : AND !sram_ctrl_restart_level : CMP !sram_ctrl_restart_level : BNE +
    AND !LK_Controller_New : BEQ +
    BRA .restart_level

+   LDA !LK_Controller_Current : AND !sram_ctrl_kill_simba : CMP !sram_ctrl_kill_simba : BNE +
    AND !LK_Controller_New : BEQ +
    BRA .kill_simba

+   LDA !LK_Controller_Current : AND !sram_ctrl_next_level : CMP !sram_ctrl_next_level : BNE +
    AND !LK_Controller_New : BEQ +
    BRA .next_level

+   LDA !LK_Controller_Current : CMP !sram_ctrl_soft_reset : BEQ .soft_reset

+   LDA !LK_Controller_Current : AND !sram_ctrl_menu : CMP !sram_ctrl_menu : BNE +
    AND !LK_Controller_New : BEQ +
    BRA .menu

  .return
+   RTL

  .soft_reset
    JML $008000 ; boot routine

  .savestate
    PHP : %ai16()
    PHB
if !FEATURE_SAVESTATES
    JSL save_state
endif
    PLB : PLP
    RTL

  .loadstate
    PHP : %ai16()
    PHB
if !FEATURE_SAVESTATES
    JSL load_state
endif
    PLB : PLP
    RTL

  .restart_level
    ; make sure level time gets recorded
    LDA #$0000 : STA !ram_TimeAttack_DoNotRecord
    ; negative to load from LK_Next_Level
    LDA #$FFFF : STA !LK_Loading_Trigger
    LDA !LK_Current_Level : STA !LK_Next_Level
    RTL

  .kill_simba
    LDA #$FFFF : STA !LK_Simba_Health
    STA !LK_Skip_Death_Scene
    RTL

  .next_level
    ; Bonus minigames would crash
    LDA !LK_Current_Level : CMP #$000A : BMI .safe
    CMP #$000E : BMI .fail
  .safe
    LDA #$0001 : STA !LK_Loading_Trigger
    RTL
  .fail
;    %sfxfail()
    RTL

  .menu
    JSL cm_start
    RTL

  .timeControl
    CMP !CTRL_LEFT : BEQ .resume
    CMP !CTRL_RIGHT : BEQ .pause
    CMP !CTRL_UP : BEQ .speedup
    CMP !CTRL_DOWN : BEQ .slowdown
    RTL
  .resume
    LDA #$0000 : STA !ram_TimeControl_mode
    STA !ram_TimeControl_frames : STA !ram_TimeControl_timer
    RTL
  .pause
    ; frame advance if already paused
    LDA !ram_TimeControl_mode : BMI .frameAdvance
    LDA #$FFFF : STA !ram_TimeControl_mode
    RTL
  .frameAdvance
    LDA #$FFFE : STA !ram_TimeControl_mode
    RTL
  .speedup
    LDA !ram_TimeControl_frames : BEQ .fail
    DEC : STA !ram_TimeControl_frames : STA !ram_TimeControl_timer
    RTL
  .slowdown
    LDA #$0001 : STA !ram_TimeControl_mode
    LDA !ram_TimeControl_mode : CMP #$000A : BPL .fail
    LDA !ram_TimeControl_frames : INC : STA !ram_TimeControl_frames : STA !ram_TimeControl_timer
    RTL
}
print pc, " ControllerShortcuts end"
