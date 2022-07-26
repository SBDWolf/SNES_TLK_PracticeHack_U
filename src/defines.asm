
!DEV_BUILD ?= 0 ; outputs debugging symbols, unhides unfinished menus
if !DEV_BUILD
!FEATURE_SAVESTATES ?= 1
else
!FEATURE_SAVESTATES ?= 0
endif
!SRAM_VERSION = #$0000 ; inc this to force initialization of new SRAM

!VERSION_MAJOR = 2
!VERSION_MINOR = 0
!VERSION_BUILD = 1
!VERSION_REV_1 = 0
!VERSION_REV_2 = 0

!TILE_CLEAR = #$0140
!TILE_BLANK = #$2540
!TILE_DECIMAL = #$255A
!TILE_HYPHEN = #$256B
!TILE_COLON = #$257A

!PALETTE_HEADER = #$21
!PALETTE_TEXT = #$25
!PALETTE_SPECIAL = #$29
!PALETTE_SELECTED = #$2D

!SKIP_DEATH = #$8000
!SKIP_PRIDE = #$0001
!SKIP_EXILE = #$0002
!SKIP_BONUS = #$0004

!CTRL_B = #$8000
!CTRL_Y = #$4000
!CTRL_SELECT = #$2000
!CTRL_START = #$1000
!CTRL_VERT = #$0C00
!CTRL_UP = #$0800
!CTRL_DOWN = #$0400
!CTRL_HORIZ = #$0300
!CTRL_LEFT = #$0200
!CTRL_RIGHT = #$0100
!CTRL_A = #$0080
!CTRL_X = #$0040
!CTRL_L = #$0020
!CTRL_R = #$0010

!ACTION_TOGGLE              = #$0000
!ACTION_TOGGLE_BIT          = #$0002
!ACTION_JSL                 = #$0004
!ACTION_NUMFIELD            = #$0006
!ACTION_CHOICE              = #$0008
!ACTION_CTRL_SHORTCUT       = #$000A
!ACTION_NUMFIELD_HEX        = #$000C
!ACTION_NUMFIELD_WORD       = #$000E
!ACTION_TOGGLE_INVERTED     = #$0010
!ACTION_NUMFIELD_COLOR      = #$0012
!ACTION_NUMFIELD_HEX_WORD   = #$0014
!ACTION_NUMFIELD_SOUND      = #$0016
!ACTION_CTRL_INPUT          = #$0018
!ACTION_TOGGLE_BIT_INVERTED = #$001A
!ACTION_JSL_SUBMENU         = #$001C
!ACTION_NUMFIELD_8BIT       = #$001E
!ACTION_NUMFIELD_DECIMAL    = #$0020
!ACTION_NUMFIELD_TIME       = #$0022


; ------------
; Hack Defines
; ------------

!LK_Controller_New = $0006

!ram_tilemap_buffer = $7EF9C0 ; 0x640

!MENU_RAM_START = $7E1E20
!MENU_RAM_SIZE = #$0060
!WRAM_START = $7E1E80
!WRAM_SIZE = #$0080
!MENU_PALETTES = $7E0100
!MENU_PALETTES_SIZE = #$004E

; Menu RAM
!ram_cm_menu_stack = !MENU_RAM_START+$00 ; 0x10
!ram_cm_cursor_stack = !MENU_RAM_START+$10 ; 0x10
!ram_cm_cursor_max = !MENU_RAM_START+$20
!ram_cm_menu_bank = !MENU_RAM_START+$22
!ram_cm_leave = !MENU_RAM_START+$24
!ram_cm_controller = !MENU_RAM_START+$26
!ram_cm_input_timer = !MENU_RAM_START+$28
!ram_cm_input_counter = !MENU_RAM_START+$2A
!ram_cm_ctrl_mode = !MENU_RAM_START+$2C
!ram_cm_ctrl_timer = !MENU_RAM_START+$2E
!ram_cm_ctrl_last_input = !MENU_RAM_START+$30
!ram_cm_stack_index = !MENU_RAM_START+$32
!ram_cm_blank_tile = !MENU_RAM_START+$34
!ram_menu_active = !MENU_RAM_START+$36

; $38..4B reserved for menu DP usage

!ram_cm_music_test = !MENU_RAM_START+$50
!ram_cm_sfx_test = !MENU_RAM_START+$52
!ram_cm_Simba_Age = !MENU_RAM_START+$54
!ram_cm_levelselect_target = !MENU_RAM_START+$56
!ram_cm_difficulty = !MENU_RAM_START+$58
; FREE SPACE ^ up to +$5F ($1E7F)

; Menu palette RAM
!ram_cm_cgram = !MENU_PALETTES+$00 ; 0x20
!ram_pal_header_outline = !MENU_PALETTES+$02 ; part of !ram_cm_cgram
!ram_pal_header_fill = !MENU_PALETTES+$06
!ram_pal_text_outline = !MENU_PALETTES+$0A
!ram_pal_text_fill = !MENU_PALETTES+$0E
!ram_pal_special_outline = !MENU_PALETTES+$12
!ram_pal_special_fill = !MENU_PALETTES+$16
!ram_pal_selected_outline = !MENU_PALETTES+$1A
!ram_pal_selected_fill = !MENU_PALETTES+$1E
!ram_pal_background = !MENU_PALETTES+$04

!ram_cm_cgram_backup = !MENU_PALETTES+$20 ; 0x20
!ram_pal_blue = !MENU_PALETTES+$40
!ram_pal_green = !MENU_PALETTES+$42
!ram_pal_red = !MENU_PALETTES+$44
!ram_pal_lo = !MENU_PALETTES+$46
!ram_pal_hi = !MENU_PALETTES+$48


; Non-menu RAM
!ram_levelselect_enable = !WRAM_START+$00
!ram_levelselect_target = !WRAM_START+$02
!ram_levelselect_nexttarget = !WRAM_START+$04
!ram_levelselect_checkpoint = !WRAM_START+$06
!ram_TimeAttack_DoNotRecord = !WRAM_START+$08
!ram_TimeControl_mode = !WRAM_START+$0A
!ram_TimeControl_frames = !WRAM_START+$0C
!ram_TimeControl_timer = !WRAM_START+$0E

!ram_death_loops = !WRAM_START+$10
!ram_play_music_track = !WRAM_START+$12
!ram_play_sfx = !WRAM_START+$14
!ram_loadstate_repeat = !WRAM_START+$16

!ram_timer_frames = !WRAM_START+$20 ; 0x1
!ram_timer_seconds = !WRAM_START+$21 ; 0x1
!ram_timer_minutes = !WRAM_START+$22 ; 0x2
!ram_timer_capped = !WRAM_START+$24
!ram_sprite_tile = !WRAM_START+$26
!ram_previous_frames = !WRAM_START+$28 ; 0x1
!ram_previous_seconds = !WRAM_START+$29 ; 0x1
!ram_previous_minutes = !WRAM_START+$2A ; 0x2
!ram_timer_recorded = !WRAM_START+$2C ; 0x2
!ram_timer_ignore = !WRAM_START+$2E ; 0x2

; FREE SPACE ^ up to +$4E

!ram_mem_editor_active = !WRAM_START+$50
!ram_mem_address_bank = !WRAM_START+$52
!ram_mem_address = !WRAM_START+$54
!ram_mem_address_hi = !WRAM_START+$56
!ram_mem_address_lo = !WRAM_START+$58
!ram_mem_memory_size = !WRAM_START+$5A
!ram_mem_editor_hi = !WRAM_START+$5C
!ram_mem_editor_lo = !WRAM_START+$5E
!ram_draw_value = !WRAM_START+$60
!ram_mem_line_position = !WRAM_START+$62
!ram_mem_loop_counter = !WRAM_START+$64
!ram_TimeControl_P1 = !WRAM_START+$66
!ram_TimeControl_P2 = !WRAM_START+$68
!LK_Controller_P2New = !WRAM_START+$6A
!LK_Controller_P2Current = !WRAM_START+$6C
!LK_Controller_P2Filtered = !WRAM_START+$6E

!ram_hex2dec_first_digit = !WRAM_START+$70
!ram_hex2dec_second_digit = !WRAM_START+$72
!ram_hex2dec_third_digit = !WRAM_START+$74
!ram_hex2dec_rest = !WRAM_START+$76

!ram_tmp_1 = !WRAM_START+$78
!ram_tmp_2 = !WRAM_START+$7A
!ram_tmp_3 = !WRAM_START+$7C
!ram_tmp_4 = !WRAM_START+$7E
; end of freespace @ $1F00


; ----
; SRAM
; ----

; $306000..7FFF = general use
; $316000..7FFF = time attack
; $336000..7FFF = crash handler
; Banks $20-2F + $37-3F = savestates

!SRAM_START = $306000
!SRAM_SIZE = #$0100

!TIMEATTACK = $316000
!TIMEATTACK_SIZE = #$005E ; 3 bytes per level, 10 levels, 3 difficulties

!sram_ctrl_menu = !SRAM_START+$00
!sram_ctrl_save_state = !SRAM_START+$02
!sram_ctrl_load_state = !SRAM_START+$04
!sram_ctrl_restart_level = !SRAM_START+$06
!sram_ctrl_next_level = !SRAM_START+$08
!sram_ctrl_kill_simba = !SRAM_START+$0A
!sram_ctrl_soft_reset = !SRAM_START+$0C

!sram_options_difficulty = !SRAM_START+$20
!sram_options_control_type = !SRAM_START+$22
!sram_options_music = !SRAM_START+$24
!sram_options_sfx = !SRAM_START+$26
!sram_skip_cutscenes = !SRAM_START+$28
!sram_fast_boot = !SRAM_START+$2A
!sram_savestate_rng = !SRAM_START+$2C
!sram_loadstate_death = !SRAM_START+$2E
!sram_loadstate_freeze = !SRAM_START+$30
!sram_loadstate_delay = !SRAM_START+$32

; FREE SPACE ^

!sram_pal_profile = !SRAM_START+$E0
!sram_cm_cgram = !SRAM_START+$E2 ; 0x12
!sram_pal_header_outline = !SRAM_START+$E2
!sram_pal_header_fill = !SRAM_START+$E4
!sram_pal_text_outline = !SRAM_START+$E6
!sram_pal_text_fill = !SRAM_START+$E8
!sram_pal_special_outline = !SRAM_START+$EA
!sram_pal_special_fill = !SRAM_START+$EC
!sram_pal_selected_outline = !SRAM_START+$EE
!sram_pal_selected_fill = !SRAM_START+$F0
!sram_pal_background = !SRAM_START+$F2
!sram_menu_background = !SRAM_START+$F4

!sram_initialized = !SRAM_START+$FE

!sram_TimeAttack = !TIMEATTACK+$00 ; 0x1
!sram_TimeAttack_frames = !TIMEATTACK+$00 ; 0x1
!sram_TimeAttack_seconds = !TIMEATTACK+$01 ; 0x1
!sram_TimeAttack_minutes = !TIMEATTACK+$02 ; 0x1


; -----------------
; Crash Handler RAM
; -----------------

!crash_tilemap_buffer = $7F8000 ; 0x800

!CRASHDUMP = $336000
!CRASHDUMP_SIZE = #$007E

!sram_crash_a = !CRASHDUMP
!sram_crash_x = !CRASHDUMP+$02
!sram_crash_y = !CRASHDUMP+$04
!sram_crash_dbp = !CRASHDUMP+$06
!sram_crash_sp = !CRASHDUMP+$08
!sram_crash_type = !CRASHDUMP+$0A
!sram_crash_draw_value = !CRASHDUMP+$0C
!sram_crash_stack_size = !CRASHDUMP+$0E

; Reserve 48 bytes for stack
!sram_crash_stack = !CRASHDUMP+$10

!sram_crash_page = !CRASHDUMP+$40
!sram_crash_palette = !CRASHDUMP+$42
!sram_crash_cursor = !CRASHDUMP+$44
!sram_crash_loop_counter = !CRASHDUMP+$46
!sram_crash_bytes_to_write = !CRASHDUMP+$48
!sram_crash_stack_line_position = !CRASHDUMP+$4A
!sram_crash_text = !CRASHDUMP+$4C
!sram_crash_text_bank = !CRASHDUMP+$4E
!sram_crash_text_palette = !CRASHDUMP+$50
!sram_crash_mem_viewer = !CRASHDUMP+$52
!sram_crash_mem_viewer_bank = !CRASHDUMP+$54
!sram_crash_temp = !CRASHDUMP+$56
!sram_crash_dp = !CRASHDUMP+$58

!sram_crash_input = !CRASHDUMP+$60
!sram_crash_input_new = !CRASHDUMP+$62
!sram_crash_input_prev = !CRASHDUMP+$64
!sram_crash_input_timer = !CRASHDUMP+$66
!sram_crash_palette_12 = !CRASHDUMP+$68
!sram_crash_palette_14 = !CRASHDUMP+$6A


; -------------------
; Lion King Addresses
; -------------------

!Cycle_RNG = $C0CBBA


!LK_Loading_State = $0008

!LK_FadeInOut_Flag = $0056 ; 0x1
!LK_2100_Brightness = $0057 ; 0x1

!LK_Controller_Filtered = $005A
!LK_Controller_Current = $005C

!LK_Exile_Cutscene = $00FA

!LK_4200_NMIEnable = $0A08
!LK_NMI_Counter = $0A0A

!LK_Title_Screen = $0A4E

!LK_Pause_Flag = $0A89

!LK_Silence_Countdown = $0AD7

!LK_RNG_Seed = $1E00 ; 0x3

!LK_Simba_Age = $7E2000
!LK_Simba_Roar = $7E2002
!LK_Simba_Health = $7E2004

!LK_BugHunt_Flag = $7E2430
!LK_BugToss_Flag = $7E2432

!LK_Loading_Trigger = $7EA692

!LK_Pridelands_Cutscene = $7EA6C4

!LK_Skip_Death_Scene = $7EA6BA

!LK_Simba_X = $7EB21B
!LK_Simba_Y = $7EB21D

!LK_Invul_Timer = $7EB259

!LK_Options_Difficulty = $7FFF92
!LK_Options_Music = $7FFF94
!LK_Options_SFX = $7FFF96
!LK_Options_Controller = $7FFF9A
!LK_Invul_Mode = $7FFF9C
!LK_Current_Level = $7FFF9E
!LK_Next_Level = $7FFFA0
!LK_Repeat_Level_Flag = $7FFFA2
!LK_Checkpoint_X = $7FFFA4
!LK_Checkpoint_Y = $7FFFA6
!LK_Continues = $7FFFA8
!LK_Lives = $7FFFAA
!LK_Simba_Health_Max = $7FFFAC
!LK_Simba_Roar_Max = $7FFFAE


; ---------------------
; Manual Symbols Export
; ---------------------
; These orgs add RAM addresses to the exported symbols
; They have no effect on the assembled rom
if !DEV_BUILD
incsrc ../resources/LK_labels.asm
endif
