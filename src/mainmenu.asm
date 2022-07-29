
org $F08000
print pc, " mainmenu.asm start"

; MainMenu must live in the same bank as the core menu code
; From here, submenus can branch off into any bank

MainMenu:
    dw #mm_goto_simba
    dw #mm_goto_levelselect
    dw #mm_goto_timeattack
    dw #mm_goto_memoryeditor
    dw #mm_goto_settings
    dw #mm_goto_ctrlshortcut
    dw #$FFFF
    dw #mm_goto_customizemenu
if !DEV_BUILD
    dw #$FFFF
    dw #test_thing
endif
    dw #$0000
    %cm_version_header("LION KING PRACTICE", !VERSION_MAJOR, !VERSION_MINOR, !VERSION_BUILD, !VERSION_REV_1, !VERSION_REV_2)
if !DEV_BUILD
    %cm_footer("DEVELOPMENT BUILD ^!VERSION_REV_1!VERSION_REV_2")
else
    %cm_footer("LKPRACTICE.SPAZER.LINK")
endif

MainMenuBanks:
; this list must match the main menu order
    dw #SimbaMenu>>16
    dw #LevelSelectMenu>>16
    dw #TimeAttackMenu>>16
    dw #MemoryEditorMenu>>16 ; dummy
    dw #SettingsMenu>>16
    dw #CtrlMenu>>16
    dw #$FFFF ; dummy
    dw #CustomizeMenu>>16
if !DEV_BUILD
    dw #$FFFF ; dummy
    dw #test_thing>>16 ; dummy
endif

mm_goto_simba:
    %cm_mainmenu("Simba", SimbaMenu)

mm_goto_levelselect:
    %cm_mainmenu("Level Select", LevelSelectMenu)

mm_goto_timeattack:
    %cm_mainmenu("Best Level Times", TimeAttackMenu)

mm_goto_settings:
    %cm_mainmenu("Settings", SettingsMenu)

mm_goto_memoryeditor:
    %cm_jsl("Memory Editor", .routine, MemoryEditorMenu)
  .routine
    ; we need to setup some variables before the menu is loaded
    PHY ; preserve menu pointer in Y
    JSL cm_editor_menu_prep

    ; manual submenu jump
    %setmenubank()
    PLY
    JML action_submenu

mm_goto_ctrlshortcut:
    %cm_mainmenu("Controller Shortcuts", CtrlMenu)

mm_goto_customizemenu:
    %cm_mainmenu("Customize Menu", CustomizeMenu)

test_thing:
    %cm_jsl("TEST THING", .routine, #$0000)
  .routine
    ; for live-editing in debugger
    NOP #64
    RTL


; ----------
; Simba Menu
; ----------

SimbaMenu:
    dw #simba_refill
    dw #$FFFF
    dw #simba_health_current
    dw #simba_health_max
    dw #simba_roar_current
    dw #simba_roar_max
    dw #$FFFF
    dw #simba_bug_toss
    dw #simba_bug_hunt
    dw #$FFFF
    dw #simba_invincibility
    dw #simba_invul_timer
    dw #simba_age
    dw #$0000
    %cm_header("SIMBA MENU")

simba_refill:
    %cm_jsl("Refill", .routine, #$0000)
  .routine
    LDA !LK_Simba_Health_Max : STA !LK_Simba_Health
    LDA !LK_Simba_Roar_Max : STA !LK_Simba_Roar
    RTL

simba_health_current:
    %cm_numfield("Current Health", !LK_Simba_Health, 1, 12, 1, 2, #0)

simba_health_max:
    %cm_numfield("Max Health", !LK_Simba_Health_Max, 4, 12, 2, 2, #0)

simba_roar_current:
    %cm_numfield("Current Roar", !LK_Simba_Roar, 0, 64, 2, 2, #0)

simba_roar_max:
    %cm_numfield("Max Roar", !LK_Simba_Roar_Max, 10, 64, 8, 8, #0)

simba_bug_toss:
    %cm_toggle("Bug Toss Collected", !LK_BugToss_Flag, $0001, #0)

simba_bug_hunt:
    %cm_toggle("Bug Hunt Collected", !LK_BugHunt_Flag, $0001, #0)

simba_invincibility:
    dw !ACTION_CHOICE
    dl #!LK_Invul_Mode
    dw #$0000
    db !PALETTE_TEXT, "Invul Mode", #$FF
    db !PALETTE_SPECIAL, "        OFF", #$FF
    db !PALETTE_SPECIAL, "         ON", #$FF
    db !PALETTE_SPECIAL, "       EASY", #$FF
    db $FF

simba_invul_timer:
    %cm_numfield_word("I-Frames", !LK_Invul_Timer, 0, 9999, 1, 20, #0)

simba_age:
    dw !ACTION_CHOICE
    dl #!ram_cm_Simba_Age
    dw #.routine
    db !PALETTE_TEXT, "Age (Buggy)", #$FF
    db !PALETTE_SPECIAL, "      YOUNG", #$FF
    db !PALETTE_SPECIAL, "      ADULT", #$FF
    db $FF
  .routine
    LDA !ram_cm_Simba_Age : BEQ .young
    LDA #$00FF
  .young
    STA !LK_Simba_Age
    RTL


; ------------
; Level Select
; ------------

LevelSelectMenu:
    dw #levelselect_list
    dw #levelselect_level
    dw #levelselect_execute
    dw #$FFFF
    dw #levelselect_checkpoint_list
    dw #levelselect_checkpoint_X
    dw #levelselect_checkpoint_Y
    dw #levelselect_checkpoint_current
    dw #levelselect_checkpoint_reset
    dw #$FFFF
    dw #levelselect_restart
    dw #levelselect_restart_checkpoint
    dw #levelselect_next_level
    dw #$0000
    %cm_header("LEVEL SELECT")

levelselect_list:
    %cm_submenu("Level Select - List View", LevelSelectListMenu)

levelselect_level:
    dw !ACTION_CHOICE
    dl #!ram_levelselect_target
    dw #$0000
    db !PALETTE_TEXT, "Target Level", #$FF
    db !PALETTE_SPECIAL, "  PRIDE LANDS", #$FF
    db !PALETTE_SPECIAL, " ROAR MONKEYS", #$FF
    db !PALETTE_SPECIAL, "ELE GRAVEYARD", #$FF
    db !PALETTE_SPECIAL, " THE STAMPEDE", #$FF
    db !PALETTE_SPECIAL, "SIMBA'S EXILE", #$FF
    db !PALETTE_SPECIAL, "HAKUNA MATATA", #$FF
    db !PALETTE_SPECIAL, "SIMBA DESTINY", #$FF
    db !PALETTE_SPECIAL, "  BE PREPARED", #$FF
    db !PALETTE_SPECIAL, "SIMBAS RETURN", #$FF
    db !PALETTE_SPECIAL, "   PRIDE ROCK", #$FF
    db !PALETTE_SPECIAL, "     BUG TOSS", #$FF
    db !PALETTE_SPECIAL, "   BUG HUNT I", #$FF
    db !PALETTE_SPECIAL, "  BUG HUNT II", #$FF
    db !PALETTE_SPECIAL, " BUG HUNT III", #$FF
    db !PALETTE_SPECIAL, "   TITLE MENU", #$FF
    db !PALETTE_SPECIAL, "     KILL HIM", #$FF
    db #$FF

levelselect_execute:
    %cm_jsl("Load Target Level", .routine, #$0000)
  .routine
    LDA !ram_levelselect_target : TAY
    JMP levelselect_execute_list
    RTL

levelselect_checkpoint_list:
    %cm_submenu("Checkpoint Load - List View", CheckpointListMenu)

levelselect_checkpoint_X:
    %cm_numfield_word("Set Checkpoint X", !LK_Checkpoint_X, 0, 8192, 1, 32, #0)

levelselect_checkpoint_Y:
    %cm_numfield_word("Set Checkpoint Y", !LK_Checkpoint_Y, 0, 8192, 1, 32, #0)

levelselect_checkpoint_current:
    %cm_jsl("Checkpoint at Current X/Y", #.routine, #$0000)
  .routine
    LDA !LK_Simba_X : STA !LK_Checkpoint_X
    LDA !LK_Simba_Y : STA !LK_Checkpoint_Y
    RTL

levelselect_checkpoint_reset:
    %cm_jsl("Reset Checkpoint to Default", #.routine, #$0016)
  .routine
    ; index = current level * 3
    LDA !LK_Current_Level : ASL : ADC !LK_Current_Level : TAX
    LDA $C00357,X : STA $38 ; addr
    LDA $C00359,X : STA $3A ; bank

    ; Y = 16
    LDA [$38],Y : STA !LK_Checkpoint_X
    LDY #$0018
    LDA [$38],Y : STA !LK_Checkpoint_Y
    RTL

levelselect_restart:
    %cm_jsl("Restart Level", #.routine, #$0000)
  .routine
    LDA !LK_Current_Level : STA !LK_Next_Level
    ; negative to load from LK_Next_Level
    LDA #$FFFF : STA !LK_Loading_Trigger
    STA !LK_Skip_Death_Scene
    STA !ram_cm_leave
    RTL


levelselect_restart_checkpoint:
    %cm_jsl("Restart with Checkpoint", #.routine, #$0000)
  .routine
    LDA #$FFFF
    STA !LK_Simba_Health : STA !LK_Skip_Death_Scene
    STA !ram_cm_leave
    JSL cm_go_back
    RTL

levelselect_next_level:
    %cm_jsl("Load Next Level", .routine, #$0001)
  .routine
    ; Bonus minigames would crash
    LDA !LK_Current_Level : CMP #$000A : BMI .safe
    CMP #$000E : BMI .fail

  .safe
    TYA : STA !LK_Loading_Trigger
    STA !ram_cm_leave
    RTL

  .fail
;    %sfxfail()
    RTL
    

LevelSelectListMenu:
    dw #levelselect_Pridelands
    dw #levelselect_RoarAtMonkeys
    dw #levelselect_ElephantGraveyard
    dw #levelselect_Stampede
    dw #levelselect_SimbasExile
    dw #levelselect_HakunaMatata
    dw #levelselect_SimbasDestiny
    dw #levelselect_BePrepared
    dw #levelselect_SimbasReturn
    dw #levelselect_PrideRock
    dw #$FFFF
    dw #levelselect_BugToss
    dw #levelselect_BugHuntI
    dw #levelselect_BugHuntII
    dw #levelselect_BugHuntIII
    dw #$FFFF
    dw #levelselect_TitleMenu
    dw #levelselect_KillHimCutscene
    dw #$0000
    %cm_header("SELECT A LEVEL")

levelselect_Pridelands:
    %cm_jsl("The Pridelands", #levelselect_execute_list, #$0000)

levelselect_RoarAtMonkeys:
    %cm_jsl("Roar at Monkeys", #levelselect_execute_list, #$0001)

levelselect_ElephantGraveyard:
    %cm_jsl("The Elephant Graveyard", #levelselect_execute_list, #$0002)

levelselect_Stampede:
    %cm_jsl("The Stampede", #levelselect_execute_list, #$0003)

levelselect_SimbasExile:
    %cm_jsl("Simba's Exile", #levelselect_execute_list, #$0004)

levelselect_HakunaMatata:
    %cm_jsl("Hakuna Matata", #levelselect_execute_list, #$0005)

levelselect_SimbasDestiny:
    %cm_jsl("Simba's Destiny", #levelselect_execute_list, #$0006)

levelselect_BePrepared:
    %cm_jsl("Be Prepared", #levelselect_execute_list, #$0007)

levelselect_SimbasReturn:
    %cm_jsl("Simba's Return", #levelselect_execute_list, #$0008)

levelselect_PrideRock:
    %cm_jsl("Pride Rock", #levelselect_execute_list, #$0009)

levelselect_BugToss:
    %cm_jsl("Bug Toss", #levelselect_execute_list, #$000A)

levelselect_BugHuntI:
    %cm_jsl("Bug Hunt I", #levelselect_execute_list, #$000B)

levelselect_BugHuntII:
    %cm_jsl("Bug Hunt II", #levelselect_execute_list, #$000C)

levelselect_BugHuntIII:
    %cm_jsl("Bug Hunt III", #levelselect_execute_list, #$000D)

levelselect_TitleMenu:
    %cm_jsl("Title Menu", #levelselect_execute_list, #$000E)

levelselect_KillHimCutscene:
    %cm_jsl("Kill Him (Exile Cutscene)", #levelselect_execute_list, #$000F)

levelselect_execute_list:
{
    ; target level in Y
    TYA : STA !ram_levelselect_target
    LDA #$0001 : STA !ram_levelselect_enable 
    STA !LK_Loading_Trigger
    STA !ram_cm_leave
    RTL
}

CheckpointListMenu:
    dw #CheckpointList_Pridelands_midway
    dw #CheckpointList_Pridelands_hyena
    dw #$FFFF
    dw #CheckpointList_RoarAtMonkeys_hippos
    dw #CheckpointList_RoarAtMonkeys_monkeys
    dw #$FFFF
    dw #CheckpointList_ElephantGraveyard_geysers
    dw #$FFFF
    dw #CheckpointList_SimbasExile_clip
    dw #$FFFF
    dw #CheckpointList_HakunaMatata_top
    dw #CheckpointList_HakunaMatata_boss
    dw #$FFFF
    dw #CheckpointList_SimbasDestiny_midway
    dw #$FFFF
    dw #CheckpointList_BePrepared_midway
    dw #CheckpointList_BePrepared_final
    dw #$0000
    %cm_header("CHECKPOINT LOAD LIST")

CheckpointList_Pridelands_midway:
    %cm_jsl("The Pridelands - Midway", #levelselect_checkpoint_load, #$0000)

CheckpointList_Pridelands_hyena:
    %cm_jsl("The Pridelands - Hyena", #levelselect_checkpoint_load, #$0004)

CheckpointList_RoarAtMonkeys_hippos:
    %cm_jsl("Roar At Monkeys - Hippos", #levelselect_checkpoint_load, #$0108)

CheckpointList_RoarAtMonkeys_monkeys:
    %cm_jsl("Roar At Monkeys - Monkeys", #levelselect_checkpoint_load, #$010C)

CheckpointList_ElephantGraveyard_geysers:
    %cm_jsl("Elephant Graveyard - Geysers", #levelselect_checkpoint_load, #$0210)

CheckpointList_SimbasExile_clip:
    %cm_jsl("Simba's Exile - Clip", #levelselect_checkpoint_load, #$0414)

CheckpointList_HakunaMatata_top:
    %cm_jsl("Hakuna Matata - Top", #levelselect_checkpoint_load, #$0518)

CheckpointList_HakunaMatata_boss:
    %cm_jsl("Hakuna Matata - Gorilla", #levelselect_checkpoint_load, #$051C)

CheckpointList_SimbasDestiny_midway:
    %cm_jsl("Simba's Destiny - Midway", #levelselect_checkpoint_load, #$0620)

CheckpointList_BePrepared_midway:
    %cm_jsl("Be Prepared - Midway", #levelselect_checkpoint_load, #$0724)

CheckpointList_BePrepared_final:
    %cm_jsl("Be Prepared - Final", #levelselect_checkpoint_load, #$0728)

levelselect_checkpoint_load:
{
    ; Y low byte = table index
    TYA : AND #$00FF : TAX

    ; load checkpoint coordinates from table
    LDA.l CheckpointListTable,X : STA !LK_Checkpoint_X
    INX #2
    LDA.l CheckpointListTable,X : STA !LK_Checkpoint_Y

    ; set flags
    LDA #$0001
    STA !ram_levelselect_checkpoint : STA !ram_TimeAttack_DoNotRecord

    ; Y high byte = level index
    TYA : AND #$FF00 : XBA : TAY
    STA !LK_Current_Level : STA !LK_Next_Level
    JML levelselect_execute_list

CheckpointListTable:
  .Pridelands        ; $00
    dw $0290, $0250 ; $00 midway
    dw $0490, $0070 ; $04 top
  .RoarAtMonkeys     ; $01
    dw $0B70, $01E0 ; $08 hippos
    dw $1270, $01E0 ; $0C monkeys
  .ElephantGraveyard ; $02
    dw $0F60, $02C0 ; $10 geysers
  .SimbasExile       ; $04
    dw $04E0, $0830 ; $14 clip
  .HakunaMatata      ; $05
    dw $03B0, $0080 ; $18 top
    dw $0B40, $0350 ; $1C gorilla
  .SimbasDestiny     ; $06
    dw $08C0, $0270 ; $20 midway
  .BePrepared        ; $07
    dw $1250, $0210 ; $24 midway
    dw $0310, $0240 ; $28 final
}


; -----------
; Time Attack
; -----------

TimeAttackMenu:
    dw TimeAttack_difficulty
    dw #$FFFF
    dw TimeAttack_Pridelands
    dw TimeAttack_RoarMonkeys
    dw TimeAttack_EleGraveyard
    dw TimeAttack_Stampede
    dw TimeAttack_SimbaExile
    dw TimeAttack_HakunaMatata
    dw TimeAttack_SimbaDestiny
    dw TimeAttack_BePrepared
    dw TimeAttack_SimbaReturn
    dw TimeAttack_PrideRock
    dw #$FFFF
    dw TimeAttack_goto_reset
    dw #$0000
    %cm_header("FASTEST LEVEL COMPLETIONS")

TimeAttack_difficulty:
    dw !ACTION_CHOICE
    dl #!ram_cm_difficulty
    dw #$0000
    db !PALETTE_TEXT, "Difficulty", #$FF
    db !PALETTE_SPECIAL, "        EASY", #$FF
    db !PALETTE_SPECIAL, "      NORMAL", #$FF
    db !PALETTE_SPECIAL, "   DIFFICULT", #$FF
    db #$FF

TimeAttack_Pridelands:
    %cm_numfield_time("The Pridelands", !sram_TimeAttack+$00, #0, #$7FFF)

TimeAttack_RoarMonkeys:
    %cm_numfield_time("Roar at Monkeys", !sram_TimeAttack+$03, #0, #$7FFF)

TimeAttack_EleGraveyard:
    %cm_numfield_time("Elephant Graveyard", !sram_TimeAttack+$06, #0, #$7FFF)

TimeAttack_Stampede:
    %cm_numfield_time("The Stampede", !sram_TimeAttack+$09, #0, #$7FFF)

TimeAttack_SimbaExile:
    %cm_numfield_time("Simba's Exile", !sram_TimeAttack+$0C, #0, #$7FFF)

TimeAttack_HakunaMatata:
    %cm_numfield_time("Hakuna Matata", !sram_TimeAttack+$0F, #0, #$7FFF)

TimeAttack_SimbaDestiny:
    %cm_numfield_time("Simba's Destiny", !sram_TimeAttack+$12, #0, #$7FFF)

TimeAttack_BePrepared:
    %cm_numfield_time("Be Prepared", !sram_TimeAttack+$15, #0, #$7FFF)

TimeAttack_SimbaReturn:
    %cm_numfield_time("Simba's Return", !sram_TimeAttack+$18, #0, #$7FFF)

TimeAttack_PrideRock:
    %cm_numfield_time("Pride Rock", !sram_TimeAttack+$1B, #0, #$7FFF)

TimeAttack_goto_reset:
    %cm_submenu("Reset A Time", #TimeAttackResetMenu)


TimeAttackResetMenu:
    dw TimeAttack_difficulty
    dw #$FFFF
    dw TimeAttack_reset_Pridelands
    dw TimeAttack_reset_RoarMonkeys
    dw TimeAttack_reset_EleGraveyard
    dw TimeAttack_reset_Stampede
    dw TimeAttack_reset_SimbaExile
    dw TimeAttack_reset_HakunaMatata
    dw TimeAttack_reset_SimbaDestiny
    dw TimeAttack_reset_BePrepared
    dw TimeAttack_reset_SimbaReturn
    dw TimeAttack_reset_PrideRock
    dw #$0000
    ; manual header/footer for brighter text
    db !PALETTE_SPECIAL, "RESET A FAST TIME", #$FF
    dw #$F007 : db !PALETTE_SPECIAL, "BEWARE, NO CONFIRMATION!", #$FF

TimeAttack_reset_Pridelands:
    %cm_numfield_time("The Pridelands", !sram_TimeAttack+$00, Reset_Fast_Time, #$0000)

TimeAttack_reset_RoarMonkeys:
    %cm_numfield_time("Roar at Monkeys", !sram_TimeAttack+$03, Reset_Fast_Time, #$0003)

TimeAttack_reset_EleGraveyard:
    %cm_numfield_time("Elephant Graveyard", !sram_TimeAttack+$06, Reset_Fast_Time, #$0006)

TimeAttack_reset_Stampede:
    %cm_numfield_time("The Stampede", !sram_TimeAttack+$09, Reset_Fast_Time, #$0009)

TimeAttack_reset_SimbaExile:
    %cm_numfield_time("Simba's Exile", !sram_TimeAttack+$0C, Reset_Fast_Time, #$000C)

TimeAttack_reset_HakunaMatata:
    %cm_numfield_time("Hakuna Matata", !sram_TimeAttack+$0F, Reset_Fast_Time, #$000F)

TimeAttack_reset_SimbaDestiny:
    %cm_numfield_time("Simba's Destiny", !sram_TimeAttack+$12, Reset_Fast_Time, #$0012)

TimeAttack_reset_BePrepared:
    %cm_numfield_time("Be Prepared", !sram_TimeAttack+$15, Reset_Fast_Time, #$0015)

TimeAttack_reset_SimbaReturn:
    %cm_numfield_time("Simba's Return", !sram_TimeAttack+$18, Reset_Fast_Time, #$0018)

TimeAttack_reset_PrideRock:
    %cm_numfield_time("Pride Rock", !sram_TimeAttack+$1B, Reset_Fast_Time, #$001B)

Reset_Fast_Time:
{
    TYA : STA $38
    LDA !ram_cm_difficulty : AND #$0003 : ASL #5 : ADC $38 : TAX
    LDA #$1010 ; 10m times = don't draw
    STA !sram_TimeAttack,X : STA !sram_TimeAttack+1,X
;    %sfxreset()
    RTL
}


; --------
; Settings
; --------

SettingsMenu:
    dw #options_difficulty
    dw #options_music
    dw #options_sfx
    dw #options_control_type
    dw #$FFFF
    dw #cutscenes_death
    dw #cutscenes_Pridelands
    dw #cutscenes_Exile
    dw #cutscenes_bonus
    dw #cutscenes_fastboot
    dw #$FFFF
    dw #lag_display
if !FEATURE_SAVESTATES
    dw #$FFFF
    dw #options_goto_savestate
endif
    dw #$0000
    %cm_header("SETTINGS MENU")
    %cm_footer("SETTINGS ARE SAVED TO SRAM")

options_difficulty:
    dw !ACTION_CHOICE
    dl #!sram_options_difficulty
    dw #.routine
    db !PALETTE_TEXT, "Difficulty", #$FF
    db !PALETTE_SPECIAL, "       EASY", #$FF
    db !PALETTE_SPECIAL, "     NORMAL", #$FF
    db !PALETTE_SPECIAL, "  DIFFICULT", #$FF
    db #$FF
  .routine
    LDA !sram_options_difficulty : STA !LK_Options_Difficulty
    RTL

options_music:
    dw !ACTION_CHOICE
    dl #!sram_options_music
    dw #.routine
    db !PALETTE_TEXT, "Music", #$FF
    db !PALETTE_SPECIAL, "        OFF", #$FF
    db !PALETTE_SPECIAL, "     STEREO", #$FF
    db !PALETTE_SPECIAL, "       MONO", #$FF
    db #$FF
  .routine
    LDA !sram_options_music : STA !LK_Options_Music
    RTL

options_sfx:
    %cm_toggle("Sound Effects", !sram_options_sfx, $0001, .routine)
  .routine
    LDA !sram_options_sfx : STA !LK_Options_SFX
    RTL

options_control_type:
    %cm_numfield("Control-Type", !sram_options_control_type, 0, 5, 1, 1, .routine)
  .routine
    LDA !sram_options_control_type : STA !LK_Options_Controller
    RTL

cutscenes_death:
    %cm_toggle_bit("Skip Death Cutscene", !sram_skip_cutscenes, !SKIP_DEATH, #0)

cutscenes_Pridelands:
    %cm_toggle_bit("Skip Pride Cutscene", !sram_skip_cutscenes, !SKIP_PRIDE, #0)

cutscenes_Exile:
    %cm_toggle_bit("Skip Exile Cutscene", !sram_skip_cutscenes, !SKIP_EXILE, #0)

cutscenes_bonus:
    %cm_toggle_bit("Skip Bonus Minigames", !sram_skip_cutscenes, !SKIP_BONUS, #0)

cutscenes_fastboot:
    %cm_toggle("Fast Boot/Reset", !sram_fast_boot, #$0001, #0)

lag_display:
    %cm_toggle("Show CPU Idle Time", !ram_lag_display, $0007, #$0000)

options_goto_savestate:
    %cm_submenu("Savestate Settings", #SavestateSettingsMenu)


; ----------
; Savestates
; ----------

SavestateSettingsMenu:
    dw #savestate_rng
    dw #loadstate_death
    dw #$FFFF
    dw #loadstate_freeze
    dw #loadstate_delay
    dw #loadstate_redraw
    dw #$0000
    %cm_header("SAVESTATE SETTINGS")
    %cm_footer("DELAY REQUIRES FREEZE ON")

savestate_rng:
    dw !ACTION_CHOICE
    dl #!sram_savestate_rng
    dw #$0000
    db !PALETTE_TEXT, "Savestate RNG", #$FF
    db !PALETTE_SPECIAL, "        OFF", #$FF
    db !PALETTE_SPECIAL, "   PRESERVE", #$FF
    db !PALETTE_SPECIAL, "RERANDOMIZE", #$FF
    db #$FF

loadstate_death:
    %cm_toggle("Loadstate on Death", !sram_loadstate_death, #$0001, #0)

loadstate_freeze:
    %cm_toggle("Freeze on Loadstate", !sram_loadstate_freeze, #$0001, #0)

loadstate_delay:
    %cm_numfield("Loadstate Freeze Delay", !sram_loadstate_delay, 0, 255, 15, 15, .routine)
  .routine
    BEQ .done
    ; enable freeze if non-zero delay
    LDA #$0001 : STA !sram_loadstate_freeze
  .done
    RTL

loadstate_redraw:
    %cm_toggle_inverted("Black Screen on Freeze", !sram_loadstate_redraw, #$0001, #0)


; ----------
; Ctrl Menu
; ----------

CtrlMenu:
    dw #ctrl_menu
if !FEATURE_SAVESTATES
    dw #ctrl_save_state
    dw #ctrl_load_state
endif
    dw #ctrl_load_restart_level
    dw #ctrl_load_next_level
    dw #ctrl_load_kill_simba
    dw #ctrl_load_soft_reset
    dw #$FFFF
    dw #ctrl_clear_shortcuts
    dw #ctrl_reset_defaults
    dw #$0000
    %cm_header("CONTROLLER SHORTCUTS")
    %cm_footer("PRESS AND HOLD FOR 2 SEC")

ctrl_menu:
    %cm_ctrl_shortcut("Main Menu", !sram_ctrl_menu)

ctrl_save_state:
    %cm_ctrl_shortcut("Save State", !sram_ctrl_save_state)

ctrl_load_state:
    %cm_ctrl_shortcut("Load State", !sram_ctrl_load_state)

ctrl_load_restart_level:
    %cm_ctrl_shortcut("Restart Level", !sram_ctrl_restart_level)

ctrl_load_next_level:
    %cm_ctrl_shortcut("Load Next Level", !sram_ctrl_next_level)

ctrl_load_kill_simba:
    %cm_ctrl_shortcut("Kill Simba", !sram_ctrl_kill_simba)

ctrl_load_soft_reset:
    %cm_ctrl_shortcut("Soft Reset", !sram_ctrl_soft_reset)

ctrl_clear_shortcuts:
    %cm_jsl("Clear Shortcuts", .routine, #$0000)
  .routine
    TYA
    STA !sram_ctrl_save_state
    STA !sram_ctrl_load_state
    STA !sram_ctrl_restart_level
    STA !sram_ctrl_next_level
    STA !sram_ctrl_kill_simba
    STA !sram_ctrl_soft_reset
    ; menu to default, Start + Select
    LDA #$3000 : STA !sram_ctrl_menu
;    %sfxquake()
    RTL

ctrl_reset_defaults:
    %cm_jsl("Reset to Defaults", .routine, #$0000)
  .routine
    LDA #$3000 : STA !sram_ctrl_menu           ; Start + Select
    LDA #$6010 : STA !sram_ctrl_save_state     ; Select + Y + R
    LDA #$6020 : STA !sram_ctrl_load_state     ; Select + Y + L
    LDA #$0000 : STA !sram_ctrl_restart_level
    LDA #$0000 : STA !sram_ctrl_next_level
    LDA #$0000 : STA !sram_ctrl_kill_simba
    LDA #$3030 : STA !sram_ctrl_soft_reset     ; Start + Select + L + R
;    %sfxquake()
    RTL

print pc, " mainmenu end"


incsrc customizemenu.asm
incsrc memoryeditor.asm

