
; These orgs generate labels in the debugging symbols
; They have no effect on the assembled ROM

; ---------
;    ROM   
; ---------

; CPU Vectors

org $008000 : Boot_Reset:
org $009E08 : NMI_Handler:
org $00FEAF : IRQ_Handler:
org $00A2E8 : BRK_Handler: ; points to bank $70, possibly SRAM on a dev cartridge
org $000000 : COP_Handler: ; effectively pointing to $00 RAM, which is normally read as BRK #$00


; System routines

org $C089AA : FadeOut_Wait15Frames: ; returns after $10 frames of fade out
org $C08E62 : Wait_For_A_Frames: ; expects number of frames (loops) in A, used during fade outs
org $C0A05D : Handle_Inputs: ; checks bit #$8000 at $1E03 for demo, Read_Controller_fromBranch otherwise
org $C0A06E : Read_Controller_long:
org $C0A072 : Read_Controller_fromBranch: ; correct the stack and fallthru to Read_Controller
org $C0A073 : Read_Controller:
org $C0A0F7 : Apply_BG12_Scrolling: ; runs every frame during NMI
org $C0A2EC : Fade_InOut: ; runs during NMI, controlled by flag at $0056, 1=fade in, 2=fade out
org $C50179 : Handle_Demo_Inputs: ; runs Read_Controller_long and then overwrites filtered inputs
org $C0A3A9 : Reset_After_Demo: ; sets pointers in $1E18 and $1E1A and then jumps to boot

org $C1CCFE : Write_MVN_Code: ; sets up a routine in RAM to run a MVN instruction and return

org $C0CBBA : Cycle_RNG:

org $C3C154 : Set_Simba_PersistentValues: ; sets max health/roar, lives, and continues based on difficulty


; Gameplay

org $C089B7 : Kill_Simba: ; loads the dea


; Audio

org $C0FA75 : Maybe_Stop_All_Sounds:

org $C22D8F : Music_FadeOut: ; runs after countdown at $0AD7 when pausing
org $C22DC2 : Music_FadeIn: ; runs when unpausing

org $C218EE : LoadA_1F00: ; Just LDA #$1F00 and RTS

; Graphics routines

org $C098F1 : Setup_PPU_Registers: ; initializes registers with constant values
org $C072F7 : CGRAM_Transfer_DF: ; runs at level loading, long address in $DF


; Misc


; Data

org $C00357 : Level_Pointer_Table: ; 24bit addresses indexed by level
org $C00387 : Level_PrideLands_Data: ; data used to load the level, +$16 = Checkpoint_X, +$18 = Checkpoint_Y

org $C09537 : IRQ_Position_Table: ; indexed by $0A02, used as vertical IRQ position



; Simba sprites appear to be uncompressed in bank $EC, starting at $EC0CA0 (PC=$2C0CA0)



; ---------
;    RAM   
; ---------

org $7EF9C0 : ram_tilemap_buffer:

org !MENU_RAM_START+$00 : ram_cm_menu_stack:
org !MENU_RAM_START+$10 : ram_cm_cursor_stack:
org !MENU_RAM_START+$20 : ram_cm_cursor_max:
org !MENU_RAM_START+$22 : ram_cm_menu_bank:
org !MENU_RAM_START+$24 : ram_cm_leave:
org !MENU_RAM_START+$26 : ram_cm_controller:
org !MENU_RAM_START+$28 : ram_cm_input_timer:
org !MENU_RAM_START+$2A : ram_cm_input_counter:
org !MENU_RAM_START+$2C : ram_cm_ctrl_mode:
org !MENU_RAM_START+$2E : ram_cm_ctrl_timer:
org !MENU_RAM_START+$30 : ram_cm_ctrl_last_input:
org !MENU_RAM_START+$32 : ram_cm_stack_index:

org !MENU_RAM_START+$36 : ram_menu_active:

org !MENU_RAM_START+$50 : ram_cm_music_test:
org !MENU_RAM_START+$52 : ram_cm_sfx_test:
org !MENU_RAM_START+$54 : ram_cm_Simba_Age:
org !MENU_RAM_START+$56 : ram_cm_levelselect_target:
org !MENU_RAM_START+$58 : ram_cm_difficulty:

org !MENU_PALETTES+$00 : ram_cm_cgram:
org !MENU_PALETTES+$02 : ram_pal_header_outline:
org !MENU_PALETTES+$06 : ram_pal_header_fill:
org !MENU_PALETTES+$0A : ram_pal_text_outline:
org !MENU_PALETTES+$0E : ram_pal_text_fill:
org !MENU_PALETTES+$12 : ram_pal_special_outline:
org !MENU_PALETTES+$16 : ram_pal_special_fill:
org !MENU_PALETTES+$1A : ram_pal_selected_outline:
org !MENU_PALETTES+$1E : ram_pal_selected_fill:
org !MENU_PALETTES+$04 : ram_pal_background:
org !MENU_PALETTES+$20 : ram_cm_cgram_backup:
org !MENU_PALETTES+$40 : sram_pal_blue:
org !MENU_PALETTES+$42 : sram_pal_green:
org !MENU_PALETTES+$44 : sram_pal_red:
org !MENU_PALETTES+$46 : ram_pal_lo:
org !MENU_PALETTES+$48 : ram_pal_hi:

org !WRAM_START+$00 : ram_levelselect_enable:
org !WRAM_START+$02 : ram_levelselect_target:
org !WRAM_START+$04 : ram_levelselect_nexttarget:
org !WRAM_START+$06 : ram_TimeAttack_DoNotRecord:

org !WRAM_START+$10 : ram_death_loops:



org !WRAM_START+$20 : ram_timer_frames:
org !WRAM_START+$21 : ram_timer_seconds:
org !WRAM_START+$22 : ram_timer_minutes:
org !WRAM_START+$24 : ram_timer_capped:
org !WRAM_START+$26 : ram_sprite_tile:
org !WRAM_START+$28 : ram_previous_frames:
org !WRAM_START+$29 : ram_previous_seconds:
org !WRAM_START+$2A : ram_previous_minutes:
org !WRAM_START+$2C : ram_timer_recorded:
org !WRAM_START+$2E : ram_timer_ignore:

org !WRAM_START+$50 : ram_mem_editor_active:
org !WRAM_START+$52 : ram_mem_address_bank:
org !WRAM_START+$54 : ram_mem_address:
org !WRAM_START+$56 : ram_mem_address_hi:
org !WRAM_START+$58 : ram_mem_address_lo:
org !WRAM_START+$5A : ram_mem_memory_size:
org !WRAM_START+$5C : ram_mem_editor_hi:
org !WRAM_START+$5E : ram_mem_editor_lo:
org !WRAM_START+$60 : ram_draw_value:
org !WRAM_START+$62 : ram_mem_line_position:
org !WRAM_START+$64 : ram_mem_loop_counter:

org !WRAM_START+$70 : ram_hex2dec_first_digit:
org !WRAM_START+$72 : ram_hex2dec_second_digit:
org !WRAM_START+$74 : ram_hex2dec_third_digit:
org !WRAM_START+$76 : ram_hex2dec_rest:

org !WRAM_START+$78 : ram_tmp_1:
org !WRAM_START+$7A : ram_tmp_2:
org !WRAM_START+$7C : ram_tmp_3:
org !WRAM_START+$7E : ram_tmp_4:


; SRAM
org !TIMEATTACK+$00 : sram_TimeAttack:

org !SRAM_START+$00 : sram_ctrl_menu:
org !SRAM_START+$02 : sram_ctrl_save_state:
org !SRAM_START+$04 : sram_ctrl_load_state:
org !SRAM_START+$06 : sram_ctrl_restart_level:
org !SRAM_START+$08 : sram_ctrl_next_level:
org !SRAM_START+$0A : sram_ctrl_kill_simba:
org !SRAM_START+$0C : sram_ctrl_soft_reset:

org !SRAM_START+$20 : sram_options_difficulty:
org !SRAM_START+$22 : sram_options_control_type:
org !SRAM_START+$24 : sram_options_music:
org !SRAM_START+$26 : sram_options_sfx:
org !SRAM_START+$28 : sram_skip_cutscenes:
org !SRAM_START+$2A : sram_savestate_rng:

org !SRAM_START+$E0 : sram_pal_profile:
org !SRAM_START+$E2 : sram_cm_cgram:
org !SRAM_START+$E2 : sram_pal_header_outline:
org !SRAM_START+$E4 : sram_pal_header_fill:
org !SRAM_START+$E6 : sram_pal_text_outline:
org !SRAM_START+$E8 : sram_pal_text_fill:
org !SRAM_START+$EA : sram_pal_special_outline:
org !SRAM_START+$EC : sram_pal_special_fill:
org !SRAM_START+$EE : sram_pal_selected_outline:
org !SRAM_START+$F0 : sram_pal_selected_fill:
org !SRAM_START+$F2 : sram_pal_background:
org !SRAM_START+$F4 : sram_menu_background:

org !SRAM_START+$FE : sram_initialized:


; TLK
org $7E0006 : LK_Controller_New:
org $7E0008 : LK_Loading_State:

org $7E0056 : LK_FadeInOut_Flag:
org $7E0057 : LK_2100_Brightness:

org $7E005A : LK_Controller_Filtered:
org $7E005C : LK_Controller_Current:

org $7E0062 : LK_Inputs_Rebound:

org $7E00FA : LK_Exile_Cutscene:

org $7E0A00 : LK_IRQ_Jump:
org $7E0A02 : LK_IRQ_Index:

org $7E0A08 : LK_4200_NMIEnable:
org $7E0A0A : LK_NMI_Counter:
org $7E0A0E : LK_NMI_Flag:

org $7E0A40 : LK_Stampede_Progress:
org $7E0A42 : LK_RNG_Related:

org $7E0A4E : LK_Title_Screen:

org $7E0A89 : LK_Pause_Flag:
org $7E0A8B : LK_Disallow_Pause:

org $7E0AD7 : LK_Silence_Countdown:

org $7E1E00 : LK_RNG_Seed:
org $7E1E03 : LK_Input_Flags:

org $7E1E0F : LK_Backup_ControllerType:
org $7E1E11 : LK_Backup_Difficulty:

org $7E2000 : LK_Simba_Age:
org $7E2002 : LK_Simba_Roar:
org $7E2004 : LK_Simba_Health:
org $7E2006 : LK_Code_MVN_Opcode:
org $7E2007 : LK_Code_MVN_Destination:
org $7E2008 : LK_Code_MVN_Source:
org $7E2009 : LK_Code_MVN_Return:
org $7E200A : LK_Lives_HUD:

org $7E2430 : LK_BugHunt_Flag:
org $7E2432 : LK_BugToss_Flag:

org $7EA68E : LK_RNG_Result:

org $7EA692 : LK_Loading_Trigger:

org $7EA6BA : LK_Skip_Death_Scene:

org $7EA6C4 : LK_Pridelands_Cutscene:

org $7EB21B : LK_Simba_X:
org $7EB21D : LK_Simba_Y:

org $7EB259 : LK_Invul_Timer:

org $7EBBC1 : LK_BugHunt3_Timer:

org $7EC0C1 : LK_BugHunt1_Timer:

org $7ECB41 : LK_BugHunt2_Timer:

org $7EF93A : LK_Current_Level_Inc:

org $7FFF90 : LK_UpsideDown_Flag:
org $7FFF92 : LK_Options_Difficulty:
org $7FFF94 : LK_Options_Music:
org $7FFF96 : LK_Options_SFX:

org $7FFF9A : LK_Options_Controller:
org $7FFF9E : LK_Current_Level:
org $7FFFA0 : LK_Next_Level:
org $7FFFA2 : LK_Repeat_Level_Flag:
org $7FFFA4 : LK_Checkpoint_X:
org $7FFFA6 : LK_Checkpoint_Y:
org $7FFFA8 : LK_Continues:
org $7FFFAA : LK_Lives:
org $7FFFAC : LK_Simba_Health_Max:
org $7FFFAE : LK_Simba_Roar_Max:

org $7FFFB4 : LK_BG2_Vert_Scrolling:


; Crash
org $7F8000 : crash_tilemap_buffer:

org $246000 : CRASHDUMP:

org !CRASHDUMP : sram_crash_a:
org !CRASHDUMP+$02 : sram_crash_x:
org !CRASHDUMP+$04 : sram_crash_y:
org !CRASHDUMP+$06 : sram_crash_dbp:
org !CRASHDUMP+$08 : sram_crash_sp:
org !CRASHDUMP+$0A : sram_crash_type:
org !CRASHDUMP+$0C : sram_crash_draw_value:
org !CRASHDUMP+$0E : sram_crash_stack_size:

; Reserve 48 bytes for stack
org !CRASHDUMP+$10 : sram_crash_stack:

org !CRASHDUMP+$40 : sram_crash_page:
org !CRASHDUMP+$42 : sram_crash_palette:
org !CRASHDUMP+$44 : sram_crash_cursor:
org !CRASHDUMP+$46 : sram_crash_loop_counter:
org !CRASHDUMP+$48 : sram_crash_bytes_to_write:
org !CRASHDUMP+$4A : sram_crash_stack_line_position:
org !CRASHDUMP+$4C : sram_crash_text:
org !CRASHDUMP+$4E : sram_crash_text_bank:
org !CRASHDUMP+$50 : sram_crash_text_palette:
org !CRASHDUMP+$52 : sram_crash_mem_viewer:
org !CRASHDUMP+$54 : sram_crash_mem_viewer_bank:
org !CRASHDUMP+$56 : sram_crash_temp:
org !CRASHDUMP+$58 : sram_crash_dp:

org !CRASHDUMP+$60 : sram_crash_input:
org !CRASHDUMP+$62 : sram_crash_input_new:
org !CRASHDUMP+$64 : sram_crash_input_prev:
org !CRASHDUMP+$66 : sram_crash_input_timer:

org !CRASHDUMP+$70 : sram_crash_palette_00:
org !CRASHDUMP+$72 : sram_crash_palette_12:
org !CRASHDUMP+$74 : sram_crash_palette_14:
org !CRASHDUMP+$76 : sram_crash_palette_16:
org !CRASHDUMP+$78 : sram_crash_palette_1A:
org !CRASHDUMP+$7A : sram_crash_palette_1C:
org !CRASHDUMP+$7C : sram_crash_palette_1E:


