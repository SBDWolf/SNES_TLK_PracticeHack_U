
; Hijack the start of boot/reset
org $008003
    JML InitRAM


org $FF0000
InitRAM:
{
    %ai16()
    ; Clear RAM at each range used by the practice hack
    LDX !MENU_RAM_SIZE
-   STZ.w !MENU_RAM_START,X
    DEX : BPL -

    LDX !WRAM_SIZE
-   STZ.w !WRAM_START,X
    DEX : BPL -

    LDX !MENU_PALETTES_SIZE
-   STZ.w !MENU_PALETTES,X
    DEX : BPL -

    ; Initialize non-zero RAM
    LDA #$007E : STA !ram_mem_address_bank
    LDA #$2004 : STA !ram_mem_address

    ; Check if SRAM has been initialized
    LDA !sram_initialized : CMP !SRAM_VERSION : BEQ .game_options
    ; Add new variables without wiping old data
    CMP #$0000 : BEQ .sram_upgrade_from_00
;    CMP #$0001 : BEQ .sram_upgrade_from_01

    JSR InitSRAM
    BRA .game_options

  .sram_upgrade_from_00
    LDA #$0001 : STA !sram_loadstate_redraw
  .sram_upgrade_from_01

  .game_options
    ; Load values from SRAM
    LDA !sram_options_difficulty : STA !LK_Options_Difficulty
    LDA !sram_options_music : STA !LK_Options_Music
    LDA !sram_options_sfx : STA !LK_Options_SFX
    LDA !sram_options_control_type : STA !LK_Options_Controller

    JML $C08009 ; skip REP #$10
}

InitSRAM_long:
; Support for "Factory Reset" from the menu, to be added later
{
    JSR InitSRAM
    RTL
}

InitSRAM:
{
    ; Default controller shortcuts
    LDA #$3000 : STA !sram_ctrl_menu           ; Start + Select
    LDA #$6010 : STA !sram_ctrl_save_state     ; Select + Y + R
    LDA #$6020 : STA !sram_ctrl_load_state     ; Select + Y + L
    LDA #$0000 : STA !sram_ctrl_restart_level
    LDA #$0000 : STA !sram_ctrl_next_level
    LDA #$0000 : STA !sram_ctrl_kill_simba
    LDA #$3030 : STA !sram_ctrl_soft_reset     ; Start + Select + L + R

    ; Default settings
    LDA #$0001 : STA !sram_options_difficulty
    LDA #$0001 : STA !sram_options_music
    LDA #$0001 : STA !sram_options_sfx
    LDA #$0000 : STA !sram_options_control_type
    LDA #$0000 : STA !sram_skip_cutscenes
    LDA #$0000 : STA !sram_fast_boot
    LDA #$0000 : STA !sram_savestate_rng
    LDA #$0000 : STA !sram_loadstate_death
    LDA #$0000 : STA !sram_loadstate_freeze
    LDA #$0000 : STA !sram_loadstate_delay
    LDA #$0001 : STA !sram_loadstate_redraw

    ; Menu customization
    LDA #$0001 : STA !sram_pal_profile
    LDA #$0000 : STA !sram_menu_background
    LDA #$001F : STA !sram_pal_header_outline
    LDA #$4B5F : STA !sram_pal_header_fill
    LDA #$365F : STA !sram_pal_text_outline
    LDA #$0095 : STA !sram_pal_text_fill
    LDA #$00FF : STA !sram_pal_special_outline
    LDA #$03FF : STA !sram_pal_special_fill
    LDA #$577D : STA !sram_pal_selected_outline
    LDA #$001F : STA !sram_pal_selected_fill
    LDA #$0000 : STA !sram_pal_background

    ; Clear crash handler SRAM
    LDA #$0000
    LDX !CRASHDUMP_SIZE
-   STA !CRASHDUMP,X
    DEX #2 : BPL -

    ; Clear TimeAttack RAM
    LDA #$1010 : LDX !TIMEATTACK_SIZE
-   STA !TIMEATTACK,X
    DEX #2 : BPL -

    ; Store SRAM initialized flag
    LDA !SRAM_VERSION : STA !sram_initialized

    RTS
}
