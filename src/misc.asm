
; Don't let the game initialize its options (diff/audio/etc)
org $C08066
    BRA Skipped_Options_Init

org $C0807C : Skipped_Options_Init:


; Skip past some boot screens to save time
org $C476C9
    JSL SkipBootScreens
    BRA $00

org $C46391
    JSL SkipWestwoodScreen
    NOP


; Load savestate upon death
org $C089BB
    JSL LoadstateOnDeath


; Skip game over check
org $C08AF3
    BRA Skip2DeathLoopProtection
    NOP #4
Skip2DeathLoopProtection:


if !FEATURE_SAVESTATES
; Detect and correct death loops
org $C08AFA
    JSL DeathLoopProtection
endif


; Don't update lives digit after getting a 1up
org $C075E0
    NOP #4


; Hijack setting of level index
org $C0894E
    ; between levels
    JSL LevelLoadingHijack

org $C53797
    ; title screen
    JSL LevelLoadingHijack


; Hijack to force loading from checkpoints
org $C08673
    JML CheckpointLoadingHijack


; Hijack to skip death cutscene
org $C08A59
    JML DeathCutsceneSkip

; Hijack Pride Lands level ending to skip cutscene
org $C14891
    JSL PridelandsCutsceneSkip

; Hijack to skip Bug Hunt
org $C08955
    JML BonusMinigameSkip

; Hijack end of game loop to display remaining CPU time
org $C0985F
    JMP LagOMeter


org $F50000
print pc, " misc.asm start"

SkipBootScreens:
{
    LDA !sram_fast_boot : BNE .skip
    LDA #$0082 : LDY #$002C ; overwritten code
    RTL

  .skip
    ; set timer to 0 frames
    LDA #$0000 : LDY #$002C
    RTL
}

SkipWestwoodScreen:
{
    LDA !sram_fast_boot : BNE .skip
    ; continue to Westwood screen
    LDA #$0001 : STA ($00),Y
    RTL

  .skip
    ; skip to title screen
    LDA #$0003 : STA ($00),Y
    RTL
}


LoadstateOnDeath:
{
    LDA !sram_loadstate_death : BNE .loadstate

  .death
    LDX #$7E : PHX : PLB
    RTL

  .loadstate
    ; ensure a save exists first
    LDA !SRAM_SAVED_STATE : CMP #$5AFE : BNE .death
    %ai16()
    JML ControllerShortcuts_loadstate
}


LevelLoadingHijack:
{
    STA $00 ; stash intended level index

    ; check if Exile cutscene
    CMP #$000F : BNE +
    LDA !sram_skip_cutscenes : BIT !SKIP_EXILE : BEQ +
    LDA #$0004 ; load Simba's Exile
    STA $00 : STA !LK_Next_Level
    BRA .return

    ; check if loading from menu
+   LDA !ram_levelselect_enable : BEQ .return
    LDA !LK_Current_Level : INC : STA !LK_Next_Level
    LDA !ram_levelselect_target : STA !LK_Current_Level
    STA !LK_Next_Level
    LDA #$0000 : STA !ram_levelselect_enable
    RTL

  .return
    JSL TimeAttack
    LDA #$0000 : STA !ram_TimeAttack_DoNotRecord
    LDA $00 : STA !LK_Current_Level
    RTL
}

CheckpointLoadingHijack:
{
    LDA !ram_levelselect_checkpoint : BNE .checkpoint
    LDA !LK_Repeat_Level_Flag ; overwritten code
    JML $C08677 ; load normally

  .checkpoint
    LDA #$0000 : STA !ram_levelselect_checkpoint
    JML $C08693 ; load from checkpoint
}


DeathCutsceneSkip:
{
    LDA !sram_skip_cutscenes : BPL .return
    ; non-zero triggers level end, negative skips cutscene
    LDA #$FFFF : STA !LK_Skip_Death_Scene

  .skip
    JML $C08AD9

  .return
    LDA !LK_Skip_Death_Scene : BNE .skip
    JML $C08A61
}

PridelandsCutsceneSkip:
{
    ; save timer to be redrawn later, includes seconds
    ; this also serves as the LevelCompleteHijack for Pridelands
+   LDA !ram_timer_frames : STA !ram_previous_frames
    LDA !ram_timer_minutes : STA !ram_previous_minutes
    LDA #$F000 : STA !ram_timer_capped ; negative if cutscene plays

    LDA !sram_skip_cutscenes : BIT !SKIP_PRIDE : BEQ .return
    ; non-zero triggers level end, negative skips cutscene
    LDA #$FFFF : STA !LK_Pridelands_Cutscene
    LDA #$0001 : STA !ram_timer_capped

  .return
    JML $C0AC84 ; overwritten jump
}

BonusMinigameSkip:
{
    LDA !sram_skip_cutscenes : BIT !SKIP_BONUS : BEQ .return
    JML $C08995 ; skip minigame checks
    
  .return
    LDA !LK_BugHunt_Flag ; overwritten code
    JML $C08959
}


DeathLoopProtection:
{
    ; check if death cutscene is disabled
    LDA !sram_skip_cutscenes : BMI .skipped

    ; check if timer less than 7 seconds (death scene included)
    LDA !ram_timer_seconds : CMP #$0008 : BPL .return
    BRA .reset

  .skipped
    LDA !ram_timer_seconds : CMP #$0002 : BPL .return

  .reset
    ; count death loops up to 4
    LDA !ram_death_loops : INC : STA !ram_death_loops
    CMP #$0004 : BMI .return

    ; reset checkpoint to default
    PHX : PHY
    LDA #$0000 : STA !ram_death_loops
    ; current level * 3 = index
    LDA !LK_Current_Level : ASL : ADC !LK_Current_Level : TAX
    ; load level info pointer
    LDA $C00357,X : STA $38
    LDA $C00359,X : STA $3A
    ; get checkpoint coordinates
    LDY #$16
    LDA [$38],Y : STA !LK_Checkpoint_X
    LDY #$18
    LDA [$38],Y : STA !LK_Checkpoint_Y
    PLY : PLX

  .return
    RTL
}


Reset_PPU_Registers:
; called by save/load routines
; mostly copying $C098F1
{
    PHP : %ai16()
    ; current level * 3 = index
    LDA !LK_Current_Level : ASL : ADC !LK_Current_Level : TAX
    ; load level info pointer
    LDA $C00357,X : STA $DF
    %a8()
    LDA $C00359,X : STA $E1

    ; common register settings
    LDA #$80 : STA $802100 ; enable forced blanking
    STZ $2106 : STZ $4200 ; clear mosaic, disable all interrupts
    STZ $210B : STZ $210C ; clear BG1-4 tileset addr
    LDA #$03 : STA $2101 ; OAM address
    LDA #$09 : STA $2105 ; Mode 1, BG3 priority on

    LDX $DF : CPX #$041D : BNE .notStampede
    ; Stampede updates BG1 tilemap addr rapidly
    LDA #$40 : STA $0A60 : STA $2107 ; BG1 tilemap addr
    LDA #$4C : STA $2108 ; BG2 tilemap addr
    PLP
    RTL

  .notStampede
    ; tilemap addresses and sizes
    LDA #$41 : STA $2107 ; BG1 tilemap addr/size
    LDA #$49 : STA $2108 ; BG2 tilemap addr/size
    LDA #$48 : STA $2109 ; BG3 tilemap addr/size
    LDA #$00 : STA $210A ; BG4 tilemap addr/size
    PLP
    RTL
}


Play_Music_Track:
{
    JSL $C07882

    JSL $C0FA75 ; Stops music and sound FX

    LDA !ram_play_music_track : PHA
    JSL $C22B06
    PLA

    LDA !ram_play_music_track : PHA
    JSL $C22E41
    PLA

    PEA $00E0 : PEA $0000
    JSL $C22CEC ; Play_SFX
    PLA : PLA

    RTL
}

Play_Level_Music:
{
    LDA !LK_Current_Level : ASL : TAX
    LDA.l LevelTrackList,X : BMI .noMusicPrideRock
    STA !ram_play_music_track
    JSL Play_Music_Track

  .noMusicPrideRock
    RTL

LevelTrackList:
    dw #$000C ; This Land, The Pridelands
    dw #$0003 ; Can't Wait, Roar at Monkeys
    dw #$000D ; Be Prepared, The Elephant Graveyard
    dw #$0000 ; To Die For, The Stampede
    dw #$000E ; King of Pride Rock, Simba's Exile
    dw #$000A ; Hakuna Matata
    dw #$000F ; Under the Stars, Simba's Destiny
    dw #$000B ; Hoo Hah, Be Prepared + Simba's Return
    dw #$000B ; Hoo Hah, Be Prepared + Simba's Return
    dw #$FFFF ; Pride Rock track unavailable with this method
    dw #$0002 ; Bug Toss
    dw #$0001 ; Bug Hunt
    dw #$0001 ; Bug Hunt
    dw #$0001 ; Bug Hunt
    dw #$0005 ; Circle of Life, Title Menu
    dw #$FFFF ; Exile cutscene track unknown
}

print pc, " misc.asm end"


org $C07FE0
LagOMeter:
; Runs at the end of the main game loop just before idling
; Reduces screen brightness for the remainder of the frame
; Darkened screen represents remaining idle time per frame
{
    LDA.w !ram_lag_display : BNE .enabled
    ; return
    LDX #$0080
    JMP $9865

  .enabled
    ; use as brightness value
    %a8()
    STA $2100
    %a16()
    ; return
    LDA #$0000
    LDX #$0080
    JMP $9865
}
warnpc $C08000
