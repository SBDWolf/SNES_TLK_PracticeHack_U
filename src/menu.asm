; -------------
; Practice Menu
; -------------

; The menu makes heavy use of direct page (DP) indirect addressing.
; The value stored in the DP address is treated as a pointer,
; and the value at that pointer address is loaded instead.
; [Square brackets] indicate long addressing, and a third byte
; of DP is used as the bank byte for 24bit addressing.

; DP offset is set to $1E20 during menu
; Add this offset to any DP (one byte) address
; Using 16 or 24 bit addressing escapes this offset

; $0000 = "Indirect JSL" address
; $0001 = "Indirect JSL" address
; $0002 = "Indirect JSL" bank
; $0003 = "Indirect JSL" bank
; $38 = various temp usage
; $39 = various temp usage
; $3A = various temp usage
; $3B = various temp usage
; $3C = toggle value, increment
; $3D = toggle value, increment
; $3E = Palette byte for text
; $3F = Palette byte for text
; $40 = menu indices, !ram_cm_menu_stack,X
; $41 = menu indices, !ram_cm_menu_stack,X
; $42 = menu bank
; $43 = menu bank
; $44 = menu item address
; $45 = menu item address
; $46 = menu item bank
; $47 = menu item bank
; $48 = RAM address, minimum value
; $49 = RAM address, minimum value
; $4A = RAM bank, maximum value
; $4B = RAM bank, maximum value

org $F00000
print pc, " menu start"

cm_start:
{
    PHP : %ai16()
    PHD : PHB
    PHX : PHY

    ; set DB to zero
    PEA $0000 : PLB : PLB

    LDA !ram_TimeControl_mode : PHA
    LDA !LK_FadeInOut_Flag : PHA

    JSR cm_init

    JSL cm_draw
    JSR cm_loop

    JSR cm_exit

    PLA : STA !LK_FadeInOut_Flag
    PLA : STA !ram_TimeControl_mode

    PLY : PLX
    PLB : PLD
    PLP
    RTL
}

cm_init:
{
    ; Set DP to the start of menu RAM
    LDA.w #!MENU_RAM_START : TCD

    %a8()
    LDA #$80 : STA $802100 ; enable forced blanking
    LDA #$09 : STA $2105   ; enable BG3 priority, Mode 1
    STZ $2111 : STZ $2111  ; BG3 horizontal offset, write twice
    STZ $2112 : STZ $2112  ; BG3 vertical scroll offset, write twice
    STZ $420C              ; disable HDMA, no shadow/mirror to restore from
    %a16()

    JSR cm_BG3_setup

    ; Setup palettes
    JSL cm_backup_cgram
    JSL cm_copy_cgram
    JSL cm_transfer_menu_cgram

    %a8()
    LDA #$0F : STA $0F2100 ; disable forced blanking
    STA !LK_2100_Brightness : STZ !LK_FadeInOut_Flag
    %ai16()

    ; Setup menu state
    LDA #$0000 : STA !ram_cm_leave
    STA !ram_cm_stack_index : STA !ram_cm_cursor_stack
    STA !ram_cm_ctrl_mode : STA !ram_cm_ctrl_timer
    STA !ram_mem_editor_active : STA !ram_TimeControl_mode

    LDA #MainMenu : STA !ram_cm_menu_stack
    LDA.w #MainMenu>>16 : STA !ram_cm_menu_bank
    LDA #$000E : STA !ram_cm_input_timer
    LDA !LK_NMI_Counter : STA !ram_cm_input_counter
    LDA #$0001 : STA !ram_menu_active ; can be used to detect if the menu is active

    ; Choose background tile (clear or solid)
    LDA !sram_menu_background : BNE .background
    LDA #$0140 ; clear
    BRA +
  .background
    LDA #$2540 ; solid
+   STA !ram_cm_blank_tile

    ; Init menu variables from game variables
    ; Generally, these _cm_ values are used as dummies
    ; and may or may not be reapplied at cm_exit
    LDA !LK_Simba_Age : BEQ +
    LDA #$0001
+   STA !ram_cm_Simba_Age
    LDA !LK_Current_Level : STA !ram_levelselect_target
    LDA !LK_Options_Difficulty : STA !ram_cm_difficulty

    %a16()
    JSL cm_calculate_max ; get max cursor index
    RTS
}

cm_exit:
{
    JSL wait_for_NMI  ; Wait for next frame

    JSL cm_transfer_menu_cgram ; restore palettes

    ; restore registers
    %a8()
    LDA !LK_Current_Level : CMP #$0E : BEQ .titleScreen
    LDA #$13 : STA $212C ; enable OBJ/BG1/BG2
    LDA #$01 : STA $2105 ; disable BG3 priority, Mode 1
    LDA !LK_2100_Brightness : STA $2100 ; disable forced blanking
    BRA .redrawHUD

  .titleScreen
    LDX #$07 : STX $212C ; Enable BG1/BG2/BG3
    LDX #$09 : STX $2105 ; BG3 priority, Mode 1
    LDX #$7C : STX $2109 ; BG3 tilemap addr to $7C00 ($F800 in VRAM)
    LDX #$77 : STX $210C ; BG3 tileset addr to $7000 ($F000 in VRAM)
    LDA !LK_2100_Brightness : STA $2100 ; disable forced blanking

  .redrawHUD
    %a16()
    JSR cm_HUD_refresh
    LDA #$0000 : TCD ; set DP back to zero before calling update_HUD routine
    LDA #$0000 : STA !ram_menu_active
    JSL UpdateHUD

    ; check if menu shortcut contains Start
    LDA !sram_ctrl_menu : AND !CTRL_START : BEQ +
    ; check for newly activated pause
    LDA !LK_Pause_Flag : BEQ +
    LDA !LK_Silence_Countdown : BEQ +
    ; clear pause flag before exiting
    STZ !LK_Pause_Flag : STZ !LK_Silence_Countdown

+   LDA #$0000 : STA !ram_menu_active
    STA !LK_Controller_Filtered : STA !LK_Controller_Current : STA !LK_Controller_New

    RTS
}

cm_BG3_setup:
{
; Setup screen for drawing text on BG3
    ; Write $640 bytes of zeroes to !ram_tilemap_buffer
    LDA #$0000 : LDX #$053E
-   STA !ram_tilemap_buffer,X
    DEX #2 : BPL -

    ; DMA transfer $400 bytes of MenuGFXTileset to $7A00/$F400 in VRAM
    %i8()
    LDX #$80 : STX $2115 ; vram inc mode
    LDA #$7A00 : STA $2116 ; vram addr
    LDA #$1801 : STA $4300 ; write to vram
    LDA #MenuGFXTileset : STA $4302 ; source addr
    LDX #MenuGFXTileset>>16 : STX $4304 ; source bank
    LDA #$0400 : STA $4305 ; size
    LDX #$01 : STX $420B ; begin transfer

    ; DMA transfer $400 bytes of ram_tilemap_buffer to $7C00/$F800 in VRAM
    ; Most values can be carried over from previous transfer, including current VRAM address
    LDA #!ram_tilemap_buffer : STA $4302 ; source addr
    LDX #!ram_tilemap_buffer>>16 : STX $4304 ; source bank
    LDA #$0400 : STA $4305 ; size
    LDX #$01 : STX $420B ; begin transfer

    ; DMA transfer the same $400 bytes of ram_tilemap_buffer to $7E00/$FC00 in VRAM
    ; Reset to beginning of tilemap buffer so we stay in the zeroes
    LDA #!ram_tilemap_buffer : STA $4302 ; source addr
    LDA #$0400 : STA $4305 ; size
    LDX #$01 : STX $420B ; begin transfer

    ; Setup BG3 registers
    LDX #$07 : STX $212C ; Enable BG1/BG2/BG3
    LDX #$09 : STX $2105 ; BG3 priority, Mode 1
    LDX #$7C : STX $2109 ; BG3 tilemap addr to $7C00 ($F800 in VRAM)
    LDX #$77 : STX $210C ; BG3 tileset addr to $7000 ($F000 in VRAM)

    %ai16()
    RTS
}

wait_for_NMI:
{
; run the same routine the game would use to wait for the next frame
; there's a lot of audio code in here, so hopefully this helps keep the APU in sync
    PHP : %ai16()
    PHX : PHY
    LDA #$0040 : LDX #$0080
    JSL $C218FA
    PLY : PLX : PLP
    RTL
}

cm_HUD_refresh:
{
; use indirect addressing to loop through object RAM in search of the two HUD bars
; exit if both have been found, or if we've searched long enough (they don't always exist)
    LDA #$0010 : STA $38 ; max object slots to check, there are over 83 counting Simba's
    LDA #$B217 : STA $3A ; first object addr pointer
    LDA #$7E7E : STA $3C ; object RAM bank
    LDA #$0002 : STA $3E ; HUD elements left to find
    LDY #$000A ; offset to object variable for current health/roar on HUD

  .loopObjectSlots
    ; check the first pointer of each slot to find the HUD elements
    LDA [$3A] : CMP #$0001 : BEQ .found ; health bar
    CMP #$D5D9 : BEQ .found ; roar bar
    LDA $3A : CLC : ADC #$0080 : STA $3A ; next object
    DEC $38 : BNE .loopObjectSlots

  .done
    RTS

  .found
    ; store an impossible value to current health/roar to force the HUD
    ; sprite to update because it doesn't match Simba's values at $7E200x
    LDA #$0050 : STA [$3A],Y
    LDA $3A : CLC : ADC #$0080 : STA $3A ; next enemy
    DEC $3E : BEQ .done ; HUD elements left to find
    DEC $38 ; objects left to check, HUD elements don't always exist
    BRA .loopObjectSlots
}

cm_backup_cgram:
{
    PHP : %a16() : %i8()
    LDX #$80 : STX $2100 ; enable forced blanking
    LDX #$00 : STX $2121 ; CGRAM address
    LDA #$3B80 : STA $4300 ; B->A, source = $213B (CGRAM read)
    LDA.w #!ram_cm_cgram_backup : STA $4302 ; destination addr
    LDX.b #!ram_cm_cgram_backup>>16 : STX $4304 ; destination bank
    LDA #$0020 : STA $4305 ; size
    LDX #$01 : STX $420B ; transfer on channel 0
    LDX #$0F : STX $2100 ; disable forced blanking
    PLP
    RTL
}

cm_transfer_menu_cgram:
{
    PHP : %a16() : %i8()
    LDX #$80 : STX $2100 ; enable forced blanking
    LDX #$00 : STX $2121 ; CGRAM address
    LDA #$2200 : STA $4300 ; B->A, source = $213B (CGRAM read)
    LDA.w #!ram_cm_cgram : STA $4302 ; destination addr
    LDX.b #!ram_cm_cgram>>16 : STX $4304 ; destination bank
    LDA #$0020 : STA $4305 ; size
    LDX #$01 : STX $420B ; transfer on channel 0
    LDX #$0F : STX $2100 ; disable forced blanking
    PLP
    RTL
}

cm_transfer_original_cgram:
{
    PHP : %a16() : %i8()
    LDX #$80 : STX $2100 ; enable forced blanking
    LDX #$00 : STX $2121 ; CGRAM address
    LDA #$2200 : STA $4300 ; B->A, source = $213B (CGRAM read)
    LDA.w #!ram_cm_cgram_backup : STA $4302 ; destination addr
    LDX.b #!ram_cm_cgram_backup>>16 : STX $4304 ; destination bank
    LDA #$0020 : STA $4305 ; size
    LDX #$01 : STX $420B ; transfer on channel 0
    LDX #$0F : STX $2100 ; disable forced blanking
    PLP
    RTL
}


; ----------
; Drawing
; ----------

cm_draw:
{
    PHP : %ai16()
    JSL cm_tilemap_bg
    JSL cm_tilemap_menu
    JSL cm_memory_editor
    JSL NMI_tilemap_transfer
    PLP
    RTL
}

cm_tilemap_bg:
{
    ; top left corner  = $042
    ; top right corner = $07C
    ; bot left corner  = $682
    ; bot right corner = $6BC
    ; Empty out !ram_tilemap_buffer
    LDA !TILE_CLEAR : LDX #$063E
-   STA !ram_tilemap_buffer,X
    DEX #2 : BPL -

    ; Interior
    LDA !ram_cm_blank_tile
    LDX #$0000 : LDY #$001B
-   STA !ram_tilemap_buffer+$044,X
    STA !ram_tilemap_buffer+$084,X
    STA !ram_tilemap_buffer+$0C4,X
    STA !ram_tilemap_buffer+$104,X
    STA !ram_tilemap_buffer+$144,X
    STA !ram_tilemap_buffer+$184,X
    STA !ram_tilemap_buffer+$1C4,X
    STA !ram_tilemap_buffer+$204,X
    STA !ram_tilemap_buffer+$244,X
    STA !ram_tilemap_buffer+$284,X
    STA !ram_tilemap_buffer+$2C4,X
    STA !ram_tilemap_buffer+$304,X
    STA !ram_tilemap_buffer+$344,X
    STA !ram_tilemap_buffer+$384,X
    STA !ram_tilemap_buffer+$3C4,X
    STA !ram_tilemap_buffer+$404,X
    STA !ram_tilemap_buffer+$444,X
    STA !ram_tilemap_buffer+$484,X
    STA !ram_tilemap_buffer+$4C4,X
    STA !ram_tilemap_buffer+$504,X
    STA !ram_tilemap_buffer+$544,X
    STA !ram_tilemap_buffer+$584,X
    STA !ram_tilemap_buffer+$5C4,X
    STA !ram_tilemap_buffer+$604,X

    INX #2
    DEY : BPL -

    RTL
}

cm_tilemap_menu:
; $3E[0x2] = palette ORA for tilemap entry (for indicating selected menu)
; $40[0x4] = menu indices
; $44[0x4] = current menu item index
{
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA $40
    LDA !ram_cm_menu_bank : STA $42 : STA $46

    LDY #$0000
  .loop
    ; start by checking if current menu item is selected by the cursor
    TYA : CMP !ram_cm_cursor_stack,X : BEQ .selected
    LDA.w !PALETTE_TEXT
    BRA .continue

  .selected
    ; ORA'd with palette byte = #$2D !PALETTE_SELECTED
    LDA #$0008

  .continue
    STA $3E

    ; check for special entries (header, blank line)
    LDA [$40],Y : BEQ .header
    CMP #$FFFF : BEQ .nextEntry
    ; check if tilemap bounds exceeded (only $640 available)
    CPX #$0640 : BPL .nextEntry
    STA $44 ; pointer to current menu item

    PHY : PHX

    ; Draw current menu item
    ; X = action index (numfield, toggle, etc)
    LDA [$44] : INC $44 : INC $44 : TAX
    JSR (cm_draw_action_table,X)

    PLX : PLY

  .nextEntry
    ; skip drawing blank lines
    INY #2 ; next menu item index
    BRA .loop

  .header
    ; Draw menu header
    STZ $3E
    TYA : CLC : ADC $40 : INC #2 : STA $44
    LDX #$00C6
    JSR cm_draw_text

    ; Optional footer
    TYA : CLC : ADC $44 : INC : STA $44
    LDA [$44] : CMP #$F007 : BNE .done

    INC $44 : INC $44 : STZ $3E
    LDX #$0606
    JSR cm_draw_text
    RTL

  .done
    DEC $44 : DEC $44
    RTL
}

NMI_tilemap_transfer:
{
    JSL wait_for_NMI  ; Wait for next frame
    PHP : %a16() : %i8()
    LDX #$80 : STX $2115 ; vram inc mode
    LDA #$7C20 : STA $2116 ; vram word addr
    LDA #$1801 : STA $4300 ; vram write mode
    LDA #!ram_tilemap_buffer : STA $4302 ; source addr
    LDA #!ram_tilemap_buffer>>16 : STA $4304 ; source bank
    LDA #$0640 : STA $4305 ; size
    LDX #$01 : STX $420B ; Enabled DMA
    PLP
    RTL
}

cm_draw_action_table:
    dw draw_toggle
    dw draw_toggle_bit
    dw draw_jsl
    dw draw_numfield
    dw draw_choice
    dw draw_ctrl_shortcut
    dw draw_numfield_hex
    dw draw_numfield_word
    dw draw_toggle_inverted
    dw draw_numfield_color
    dw draw_numfield_hex_word
    dw draw_numfield_sound
    dw draw_controller_input
    dw draw_toggle_bit_inverted
    dw draw_jsl_submenu
    dw draw_numfield_8bit
    dw draw_numfield_decimal
    dw draw_numfield_time

draw_toggle:
; $3C[0x2] = toggle value (bitmask)
; $3E[0x2] = palette ORA for tilemap entry)
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; grab the toggle value
    LDA [$44] : AND #$00FF : INC $44 : STA $3C

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    %a8()

    ; grab the value at that memory address
    LDA [$48] : CMP $3C : BEQ .checked

    ; Off
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+0,X
    LDA #$2945 : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+2,X
    LDA #$294D : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_inverted:
; $3C[0x2] = toggle value (bitmask)
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; grab the toggle value
    LDA [$44] : AND #$00FF : INC $44 : STA $3C

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    %a8()

    ; check the value at that memory address
    LDA [$48] : CMP $3C : BNE .checked

    ; Off
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+0,X
    LDA #$2945 : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+2,X
    LDA #$294D : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_bit:
; $3C[0x2] = toggle value (bitmask)
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; grab bitmask
    LDA [$44] : INC $44 : INC $44 : STA $3C

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    ; check the value at that memory address
    LDA [$48] : AND $3C : BNE .checked

    ; Off
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+0,X
    LDA #$2945 : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+2,X
    LDA #$294D : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_bit_inverted:
; $3C[0x2] = toggle value (bitmask)
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; grab bitmask
    LDA [$44] : INC $44 : INC $44 : STA $3C

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    ; check the value at that memory address
    LDA [$48] : AND $3C : BEQ .checked

    ; Off
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+0,X
    LDA #$2945 : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA #$294E : STA !ram_tilemap_buffer+2,X
    LDA #$294D : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_jsl_submenu:
draw_jsl:
; $44[0x4] = current menu item index
{
    ; skip JSL address
    INC $44 : INC $44

    ; skip argument
    INC $44 : INC $44

    ; draw text normally
    %item_index_to_vram_index()
    JSR cm_draw_text
    RTS
}

draw_numfield_8bit:
draw_numfield:
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip bounds and increment values
    INC $44 : INC $44 : INC $44 : INC $44

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002C : TAX

    LDA [$48] : AND #$00FF : JSL cm_hex2dec

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X
                      STA !ram_tilemap_buffer+4,X

    ; Set palette
    %a8()
    LDA.b !PALETTE_SPECIAL : STA $3F
    LDA.b #$60 : STA $3E ; points to row of number tiles in VRAM

    ; Draw numbers
    %a16()
    ; ones
    LDA !ram_hex2dec_third_digit : CLC : ADC $3E : STA !ram_tilemap_buffer+4,X

    ; tens
    LDA !ram_hex2dec_second_digit : ORA !ram_hex2dec_first_digit : BEQ .done
    LDA !ram_hex2dec_second_digit : CLC : ADC $3E : STA !ram_tilemap_buffer+2,X

    LDA !ram_hex2dec_first_digit : BEQ .done
    CLC : ADC $3E : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_decimal:
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip bounds and increment values
    INC $44 : INC $44 : INC $44 : INC $44

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002E : TAX

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X

    ; Set palette
    %a8()
    LDA.b !PALETTE_SPECIAL : STA $3F
    LDA.b #$60 : STA $3E ; points to row of number tiles in VRAM

    LDA [$48] : TAY
    %a16()

    ; Draw numbers
    ; ones
    AND #$000F : CLC : ADC $3E : STA !ram_tilemap_buffer+2,X

    ; tens
    TYA : AND #$00F0 : BEQ .done
    LSR #4 : CLC : ADC $3E : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_word:
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip bounds and increment values
    INC $44 : INC $44 : INC $44 : INC $44
    INC $44 : INC $44 : INC $44 : INC $44

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002A : TAX

    LDA [$48] : JSL cm_hex2dec

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X
                      STA !ram_tilemap_buffer+4,X
                      STA !ram_tilemap_buffer+6,X

    ; Set palette and tile row
    %a8()
    LDA.b !PALETTE_SPECIAL : STA $3F
    LDA.b #$60 : STA $3E ; points to row of number tiles

    ; Draw numbers, which are tiles 60-69 in VRAM
    %a16()
    ; ones
    LDA !ram_hex2dec_third_digit : CLC : ADC $3E : STA !ram_tilemap_buffer+6,X

    ; tens
    LDA !ram_hex2dec_second_digit : ORA !ram_hex2dec_first_digit
    ORA !ram_hex2dec_rest : BEQ .done
    LDA !ram_hex2dec_second_digit : CLC : ADC $3E : STA !ram_tilemap_buffer+4,X

    LDA !ram_hex2dec_first_digit : ORA !ram_hex2dec_rest : BEQ .done
    LDA !ram_hex2dec_first_digit : CLC : ADC $3E : STA !ram_tilemap_buffer+2,X

    LDA !ram_hex2dec_rest : BEQ .done
    CLC : ADC $3E : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_time:
; $38[0x2] = 16bit decimal frames
; $3A[0x2] = 16bit decimal seconds
; $3C[0x2] = 16bit decimal minutes
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to load
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip JSL target
    INC $44 : INC $44

    ; skip JSL argument
    INC $44 : INC $44

    ; draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the input
    TXA : CLC : ADC #$0024 : TAX

    ; set data bank for number table
    %a8()
    PHB : LDA.b #NumberGFXTable>>16 : PHA : PLB

    ; load the time
    LDA #$00 : XBA ; clear high byte
    LDA !ram_cm_difficulty : ASL #5
    ADC #$02 : TAY
    LDA [$48],Y : CMP #$10 : BPL .done
    STA $3C : DEY ; minutes
    LDA [$48],Y : STA $3A : DEY ; seconds
    LDA [$48],Y : STA $38 ; frames
    %a16()

    ; draw minutes digit
    LDA $3C : AND #$000F : ASL : TAY
    INX #2
    LDA.w HexToNumberGFX2,Y : STA !ram_tilemap_buffer,X
    INX #2

    ; draw colons
    LDA !TILE_COLON
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+6,X
    INX #2

    ; draw seconds digits
    LDA $3A : AND #$00FF : JSL cm_dec2hex
    ASL : TAY
    LDA.w HexToNumberGFX1,Y : STA !ram_tilemap_buffer,X
    INX #2
    LDA.w HexToNumberGFX2,Y : STA !ram_tilemap_buffer,X
    INX #4 ; skip a tile for the colon

    ; draw frames digits
    LDA $38 : AND #$00FF : JSL cm_dec2hex
    ASL : TAY
    LDA.w HexToNumberGFX1,Y : STA !ram_tilemap_buffer,X
    INX #2
    LDA.w HexToNumberGFX2,Y : STA !ram_tilemap_buffer,X
    INX #2

  .done
    %a16()
    PLB
    RTS
}

draw_numfield_sound:
draw_numfield_hex:
; $38[0x2] = 8bit value (low byte) at memory address
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip bounds and increment values
    INC $44 : INC $44 : INC $44 : INC $44

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002E : TAX

    ; load 8bit value from address
    LDA [$48] : AND #$00FF : STA $38

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X

    ; Set data bank for HexGFXTable
    PHB
    LDA.w #HexGFXTable>>16 : XBA : PHA
    PLB : PLB

    ; Draw numbers
    ; (00X0)
    LDA $38 : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    
    ; (000X)
    LDA $38 : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X

    PLB
    RTS
}

draw_numfield_color:
; $38[0x2] = 8bit value (low byte) at memory address
; $3E[0x2] = temp RAM for math
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; increment past JSL
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002E : TAX

    ; load 8bit value from address
    LDA [$48] : AND #$00FF : STA $38

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X

    ; Set data bank for HexGFXTable
    PHB
    LDA.w #HexGFXTable>>16 : XBA : PHA
    PLB : PLB

    ; Draw numbers
    ; (00X0)
    LDA $38 : AND #$001E : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X

    ; (000X)
    LDA $38 : AND #$0001 : ASL #4 : STA $3E
    LDA $38 : AND #$001C : LSR : CLC : ADC $3E : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X

    PLB
    RTS
}

draw_numfield_hex_word:
; $38[0x2] = value at memory address
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002C : TAX

    ; load value from address
    LDA [$48] : STA $38

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                      STA !ram_tilemap_buffer+2,X
                      STA !ram_tilemap_buffer+4,X
                      STA !ram_tilemap_buffer+6,X

    ; Set data bank for HexGFXTable
    PHB
    LDA.w #HexGFXTable>>16 : XBA : PHA
    PLB : PLB

    ; Draw numbers
    ; (X000)
    LDA $38 : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X

    ; (0X00)
    LDA $38 : AND #$0F00 : XBA : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; (00X0)
    LDA $38 : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+4,X

    ; (000X)
    LDA $38 : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+6,X

    PLB
    RTS
}

draw_choice:
; $38[0x2] = value at memory address
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : INC $44 : STA $4A

    ; skip JSL target
    INC $44 : INC $44

    ; Draw the text first
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for choice
    TXA : CLC : ADC #$001C : TAX

    ; use address as index
    LDA [$48] : TAY

    ; find the correct text that should be drawn (the selected choice)
    ; read through the text and DEY until zero to find selected choice
    INY #2 ; skip the first text that we already drew
  .loop_choices
    DEY : BEQ .found

  .loop_text
    ; text is 8bit, pointer is 16bit :( 
    LDA [$44] : %a16() : INC $44 : %a8()
    CMP #$FF : BEQ .loop_choices
    BRA .loop_text

  .found
    %a16()
    JSR cm_draw_text

    %a16()
    RTS
}

draw_ctrl_shortcut:
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    LDA [$44] : INC $44 : INC $44 : STA $48
    LDA [$44] : STA $4A : INC $44

    %item_index_to_vram_index()
    PHX
    JSR cm_draw_text
    PLA : CLC : ADC #$0022 : TAX

    LDA [$48]
    JSR menu_ctrl_input_display

    RTS
}

draw_controller_input:
; unused, needs ram addresses from the game to function
; $44[0x4] = current menu item index
; $48[0x4] = memory address (long) to manipulate
{
    ; grab the memory address (long)
    LDA [$44] : INC $44 : INC $44 : STA $48
;    STA !ram_cm_ctrl_assign
    LDA [$44] : INC $44 : STA $4A

    ; skip JSL target
;    INC $44 : INC $44

    ; skip JSL argument
    INC $44 : INC $44

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the input
    TXA : CLC : ADC #$0020 : TAX

    LDA ($48) : AND #$E0F0 : BEQ .unbound

    ; determine which input to draw, using Y to refresh A
    TAY : AND #$0080 : BEQ + : LDY #$0000 : BRA .draw
+   TYA : AND #$8000 : BEQ + : LDY #$0002 : BRA .draw
+   TYA : AND #$0040 : BEQ + : LDY #$0004 : BRA .draw
+   TYA : AND #$4000 : BEQ + : LDY #$0006 : BRA .draw
+   TYA : AND #$0020 : BEQ + : LDY #$0008 : BRA .draw
+   TYA : AND #$0010 : BEQ + : LDY #$000A : BRA .draw
+   TYA : AND #$2000 : BEQ .unbound : LDY #$000C

  .draw
    LDA.w CtrlMenuGFXTable,Y : STA !ram_tilemap_buffer,X
    RTS

  .unbound
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer,X
    RTS

CtrlMenuGFXTable:
; update these tiles if we do use this in TLK
    ;  A      B      X      Y      L      R      Select
    ;  0080   8000   0040   4000   0020   0010   2000
    dw $288F, $2887, $288E, $2886, $288D, $288C, $2885
}

cm_draw_text:
; X = pointer to tilemap area (STA !ram_tilemap_buffer,X)
; $3E[0x2] = palette ORA for tilemap entry
; $44[0x4] = pointer to current text
{
    %a8()
    LDY #$0000
    ; FF = terminator
    LDA [$44],Y : INY : CMP #$FF : BEQ .end

    ; Special palette shouldn't be "selected"
    CMP !PALETTE_SPECIAL : BNE +
    STA $3E : BRA .loop

    ; ORA with palette info
+   ORA $3E : STA $3E

  .loop
    LDA [$44],Y : CMP #$FF : BEQ .end    ; check if terminator
    STA !ram_tilemap_buffer,X : INX      ; store tile
    LDA $3E : STA !ram_tilemap_buffer,X  ; store palette
    INX : INY
    JMP .loop

  .end
    %a16()
    RTS
}

; --------------
; Input Display
; --------------

menu_ctrl_input_display:
; $3E[0x2] = palette ORA for tilemap entry
{
    ; X = pointer to tilemap area (STA !ram_tilemap_buffer,X)
    ; A = Controller word
    JSR menu_ctrl_clear_input_display

    XBA
    LDY #$0000
  .loop
    PHA
    BIT #$0001 : BEQ .no_draw

    TYA : CLC : ADC #$0070
    XBA : ORA $3E : XBA
    STA !ram_tilemap_buffer,X : INX #2

  .no_draw
    PLA
    INY : LSR : BNE .loop

  .done
    RTS
}


menu_ctrl_clear_input_display:
{
    ; X = pointer to tilemap area
    PHA
    LDA !ram_cm_blank_tile
    STA !ram_tilemap_buffer+0,X
    STA !ram_tilemap_buffer+2,X
    STA !ram_tilemap_buffer+4,X
    STA !ram_tilemap_buffer+6,X
    STA !ram_tilemap_buffer+8,X
    STA !ram_tilemap_buffer+10,X
    STA !ram_tilemap_buffer+12,X
    STA !ram_tilemap_buffer+14,X
    STA !ram_tilemap_buffer+16,X
    PLA
    RTS
}


; ---------
; Logic
; ---------

cm_loop:
{
    JSL wait_for_NMI  ; Wait for next frame
    %a8()
    LDA #$0F : STA $0F2100 ; ensure full brightness
    %a16()

    LDA !ram_cm_leave : BEQ +
    RTS ; Exit menu loop

    ; check if configuring controller shortcuts
+   LDA !ram_cm_ctrl_mode : BEQ +
    JSR cm_ctrl_mode
    BRA cm_loop

    ; check for player input
+   JSR cm_get_inputs : STA !ram_cm_controller : BEQ cm_loop

    BIT !CTRL_A : BNE .pressedA
    BIT !CTRL_B : BNE .pressedB
    BIT !CTRL_X : BNE .pressedX
    BIT !CTRL_Y : BNE .pressedY
    BIT !CTRL_SELECT : BNE .pressedSelect
    BIT !CTRL_START : BNE .pressedStart
    BIT !CTRL_UP : BNE .pressedUp
    BIT !CTRL_DOWN : BNE .pressedDown
    BIT !CTRL_RIGHT : BNE .pressedRight
    BIT !CTRL_LEFT : BNE .pressedLeft
    BIT !CTRL_L : BNE .pressedL
    BIT !CTRL_R : BNE .pressedR
    BRA cm_loop

  .pressedB
    JSL cm_previous_menu
    BRA .redraw

  .pressedDown
    LDA #$0002
    JSR cm_move
    BRA .redraw

  .pressedUp
    LDA #$FFFE
    JSR cm_move
    BRA .redraw

  .pressedA
  .pressedY
  .pressedX
  .pressedLeft
  .pressedRight
    JSR cm_execute
    BRA .redraw

  .pressedStart
  .pressedSelect
    LDA #$0001 : STA !ram_cm_leave
    JMP cm_loop
    BRA .redraw

  .pressedL
    LDX.w !ram_cm_stack_index
    LDA #$0000 : STA !ram_cm_cursor_stack,X
;    %sfxmove()
    BRA .redraw

  .pressedR
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_cursor_max : DEC #2 : STA !ram_cm_cursor_stack,X
;    %sfxmove()

  .redraw
    JSL cm_draw
    JMP cm_loop
}

cm_ctrl_mode:
; $38[0x2] = current inputs
; $3E[0x2] = palette ORA for tilemap entry
{
    JSL ReadControllerInputs_long
    LDA !LK_Controller_Current

    ; set palette
    %a8() : LDA !PALETTE_SPECIAL : STA $3E : %a16()

    LDA !LK_Controller_Current : BEQ .clear_and_draw
    CMP !ram_cm_ctrl_last_input : BNE .clear_and_draw

    ; Holding an input for more than one second
    LDA !ram_cm_ctrl_timer : INC : STA !ram_cm_ctrl_timer : CMP.w #0060 : BNE .next_frame

    LDA !LK_Controller_Current : STA [$38]
;    %sfx macro goes here
    BRA .exit

  .clear_and_draw
    STA !ram_cm_ctrl_last_input
    LDA #$0000 : STA !ram_cm_ctrl_timer

    ; Put text cursor in X
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_cursor_stack,X : ASL #5 : CLC : ADC #$0168 : TAX

    ; Input display
    LDA !LK_Controller_Current
    JSR menu_ctrl_input_display
    JSL NMI_tilemap_transfer

  .next_frame
    RTS

  .exit
    LDA #$0000
    STA !ram_cm_ctrl_last_input
    STA !ram_cm_ctrl_mode
    STA !ram_cm_ctrl_timer
    JSL cm_draw
    RTS
}

cm_previous_menu:
{
    JSL cm_go_back
    JSL cm_calculate_max
    RTL
}

cm_go_back:
{
    ; make sure next time we go to a submenu, we start on the first line.
    LDX.w !ram_cm_stack_index
    LDA #$0000 : STA !ram_cm_cursor_stack,X

    ; make sure we don't set a negative number
    LDA !ram_cm_stack_index : DEC #2 : BPL .done

    ; exit menu if it was negative
    LDA #$0001 : STA !ram_cm_leave
    LDA #$0000

  .done
    STA !ram_cm_stack_index    
    LDA !ram_cm_stack_index : BNE .end
    LDA.l #MainMenu>>16       ; Reset submenu bank when back at main menu
    STA !ram_cm_menu_bank
    LDA #$0000 : STA !ram_mem_editor_active

  .end
;    %sfxgoback()
    RTL
}

cm_calculate_max:
; Determines the cursor's max/last position
; $40[0x4] = menu indices
{
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA $40
    LDA !ram_cm_menu_bank : STA $42

    LDX #$0000
  .loop
    LDA [$40] : BEQ .done
    INC $40 : INC $40
    INX #2
    BRA .loop

  .done
    ; stored as last index + 2
    TXA : STA !ram_cm_cursor_max
    RTL
}

cm_get_inputs:
{
    JSL ReadControllerInputs_long

    ; Check for new inputs
    LDA !LK_Controller_New : BEQ .check_holding

    ; Initial delay of 15 frames
    LDA #$000E : STA !ram_cm_input_timer

    ; Return the new input
    LDA !LK_Controller_New
    RTS

  .check_holding
    ; Check if we're holding the dpad
    LDA !LK_Controller_Current : AND #$0F00 : BEQ .noinput

    ; Decrement delay timer and check if it's zero
    LDA !ram_cm_input_timer : DEC : STA !ram_cm_input_timer : BNE .noinput

    ; Set new delay to two frames and return the (DPAD+Y) input we're holding
    ; Holding Y can be an alternate way to scroll numbers faster, but mostly unused (see draw_numfield_sound)
    LDA #$0002 : STA !ram_cm_input_timer
    LDA !LK_Controller_Current : AND #$4F00 : ORA #$0001
    RTS

  .noinput
    ; return zero if not a new input or held DPAD input
    LDA #$0000
    RTS
}

cm_move:
; $38[0x2] = number of lines moved * 2
; $40[0x4] = current menu item index
{
    STA $38
    LDX.w !ram_cm_stack_index
    CLC : ADC !ram_cm_cursor_stack,X : BPL .positive
    LDA !ram_cm_cursor_max : DEC #2 : BRA .inBounds

  .positive
    CMP !ram_cm_cursor_max : BNE .inBounds
    LDA #$0000

  .inBounds
    STA !ram_cm_cursor_stack,X : TAY

    LDA !ram_cm_menu_stack,X : STA $40
    LDA !ram_cm_menu_bank : STA $42

    ; check for blank menu line ($FFFF)
    LDA [$40],Y : CMP #$FFFF : BNE .end

    LDA $38 : BRA cm_move

  .end
;    %sfxmove()
    RTS
}

action_mainmenu:
{
    PHB
    ; Set bank of new menu
    LDA !ram_cm_cursor_stack : TAX
    LDA.l MainMenuBanks,X : STA !ram_cm_menu_bank
    STA $42 : STA $46

    BRA action_submenu_skipStackOp
}

action_submenu:
{
    PHB
  .skipStackOp
    ; Increment stack pointer by 2, then store current menu
    LDA !ram_cm_stack_index : INC #2 : STA !ram_cm_stack_index : TAX
    TYA : STA !ram_cm_menu_stack,X

  .jump
    LDA #$0000 : STA !ram_cm_cursor_stack,X

;    %sfxmove()
    JSL cm_calculate_max
    JSL cm_colors
    JSL cm_draw

    PLB
    RTL
}


; --------
; Execute
; --------

cm_execute:
; $40[0x4] = submenu item, current menu item index
{
    ; $40 = submenu item
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA $40
    LDA !ram_cm_menu_bank : STA $42
    LDA !ram_cm_cursor_stack,X : TAY
    LDA [$40],Y : STA $40

    ; Load and increment past the action index
    LDA [$40] : INC $40 : INC $40 : TAX

    ; Safety net incase blank line selected
    CPX #$FFFF : BEQ +

    ; Execute action
    JSR (cm_execute_action_table,X)
+   RTS
}

cm_execute_action_table:
    dw execute_toggle
    dw execute_toggle_bit
    dw execute_jsl
    dw execute_numfield
    dw execute_choice
    dw execute_ctrl_shortcut
    dw execute_numfield_hex
    dw execute_numfield_word
    dw execute_toggle
    dw execute_numfield_color
    dw execute_numfield_hex_word
    dw execute_numfield_sound
    dw execute_controller_input
    dw execute_toggle_bit
    dw execute_jsl_submenu
    dw execute_numfield_8bit
    dw execute_numfield_decimal
    dw execute_numfield_time

execute_toggle:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = toggle value (bitmask)
{
    ; Grab address
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    ; Load which bit(s) to toggle, 8-bit only
    LDA [$40] : INC $40 : AND #$00FF : STA $48

    ; Grab JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; On or Off?
    %a8()
    LDA [$44] : CMP $48 : BEQ .toggleOff

    ; Store toggle value to address
    LDA $48 : STA [$44]
    BRA .jsl

  .toggleOff
    ; Clear memory address
    LDA #$00 : STA [$44]

  .jsl
    ; Check if JSL target exists
    %a16()
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_toggle_bit:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = toggle value (bitmask)
{
    ; Load the address
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    ; Load which bit(s) to toggle
    LDA [$40] : INC $40 : INC $40 : STA $48

    ; Load JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; Toggle the bit
    LDA [$44] : EOR $48 : STA [$44]

    ; Check if JSL target exists
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_jsl_submenu:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; $0000 = JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; Set bank of action_submenu
    ; instead of the menu we're jumping to
    LDA.l #action_submenu>>16 : STA $0002

    ; Set return address for indirect JSL
    PHK : PEA .end-1

    ; Y = Argument
    LDA [$40] : TAY

    ; Jump to routine
    LDX #$0000
    JML [$0000]

  .end
    %ai16()
    RTS
}

execute_jsl:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; $0000 = JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Y = Argument
    LDA [$40] : TAY

    ; Jump to routine
    LDX #$0000
    JML [$0000]

  .end
    %ai16()
    RTS
}

execute_numfield_hex:
execute_numfield:
; $0000[0x4] = indirect long jump pointer
; $3C[0x2] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
; $4A[0x2] = maximum value plus one
{
    ; Load memory address to manipulate
    LDA [$40] : INC $40 : INC $40 : STA $44 ; addr
    LDA [$40] : INC $40 : STA $46 ; bank

    ; Load minimum and maximum values
    LDA [$40] : INC $40 : AND #$00FF : STA $48 ; max
    LDA [$40] : INC $40 : AND #$00FF : INC : STA $4A ; min, INC for convenience

    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    ; Load the normal increment value
    LDA [$40] : INC $40 : INC $40 : AND #$00FF : STA $3C
    BRA .load_jsl_target

  .input_held
    ; Load the faster increment value
    INC $40 : LDA [$40] : INC $40 : AND #$00FF : STA $3C

  .load_jsl_target
    ; Load pointer for routine to run next
    LDA [$40] : INC $40 : INC $40 : STA $0000

    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left
    ; pressed right, inc
    LDA [$44] : CLC : ADC $3C
    CMP $4A : BCS .set_to_min
    PHP : %a8() : STA [$44] : PLP : BRA .jsl

  .pressed_left ; dec
    LDA [$44] : SEC : SBC $3C
    CMP $48 : BMI .set_to_max
    CMP $4A : BCS .set_to_max
    PHP : %a8() : STA [$44] : PLP : BRA .jsl

  .set_to_min
    LDA $48 : PHP : %a8() : STA [$44] : PLP : CLC : BRA .jsl

  .set_to_max
    LDA $4A : DEC : PHP : %a8() : STA [$44] : PLP : CLC

  .jsl
    ; Check if JSL target exists
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_8bit:
; $0000[0x4] = indirect long jump pointer
; $3C[0x2] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
; $4A[0x2] = maximum value plus one
{
    ; Load memory address to manipulate
    LDA [$40] : INC $40 : INC $40 : STA $44 ; addr
    LDA [$40] : INC $40 : STA $46 ; bank

    ; Load min/max values
    LDA [$40] : INC $40 : AND #$00FF : STA $48
    LDA [$40] : INC $40 : AND #$00FF : INC : STA $4A ; INC for convenience

    ; Check if input held flag is set
    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    ; Use normal increment value
    LDA [$40] : INC $40 : INC $40 : AND #$00FF : STA $3C
    BRA .load_jsl_target

  .input_held
    ; Use the faster increment value
    INC $40 : LDA [$40] : INC $40 : AND #$00FF : STA $3C

  .load_jsl_target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; Check direction input
    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left

    ; Pressed right, inc
    LDA [$44] : AND #$00FF : CLC : ADC $3C

    ; Check if above maximum
    CMP $4A : BCS .set_to_min

    ; Store 8-bit value
    PHP : %a8() : STA [$44] : PLP
    BRA .jsl

  .pressed_left ; dec
    LDA [$44] : AND #$00FF : SEC : SBC $3C
    ; Check if below minimum
    CMP $48 : BMI .set_to_max

    ; Check if above maximum
    CMP $4A : BCS .set_to_min

    ; Store 8-bit value
    PHP : %a8() : STA [$44] : PLP
    BRA .jsl

  .set_to_min
    LDA $48
    PHP : %a8() : STA [$44] : PLP
    CLC : BRA .jsl

  .set_to_max
    LDA $4A : DEC
    PHP : %a8() : STA [$44] : PLP
    CLC

  .jsl
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load 8-bit address in A and jump to routine
    LDA [$44] : AND #$00FF
    LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_decimal:
; $0000[0x4] = indirect long jump pointer
; $3C[0x2] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
; $4A[0x2] = maximum value
{
    ; Load memory address to manipulate
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    LDA [$40] : INC $40 : AND #$00FF : STA $48
    LDA [$40] : INC $40 : AND #$00FF : INC : STA $4A ; INC for convenience

    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    LDA [$40] : INC $40 : INC $40 : AND #$00FF : STA $3C
    BRA .inc_or_dec

  .input_held
    INC $40 : LDA [$40] : INC $40 : AND #$00FF : STA $3C

  .inc_or_dec
    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left
    LDA [$44] : AND #$00FF : JSL cm_dec2hex
    
    CLC : ADC $3C
    CMP $4A : BCS .set_to_min

    JSL cm_hex2dec
    LDA !ram_hex2dec_second_digit : ASL #4
    ORA !ram_hex2dec_third_digit

    PHP : %a8() : STA [$44] : PLP : BRA .jsl

  .pressed_left
    LDA [$44] : AND #$00FF : JSL cm_dec2hex
    
    SEC : SBC $3C : CMP $48 : BMI .set_to_max
    CMP $4A : BCS .set_to_max

    JSL cm_hex2dec
    LDA !ram_hex2dec_second_digit : ASL #4
    ORA !ram_hex2dec_third_digit

    PHP : %a8() : STA [$44] : PLP : BRA .jsl

  .set_to_min
    LDA $48 : JSL cm_hex2dec
    LDA !ram_hex2dec_second_digit : ASL #4
    ORA !ram_hex2dec_third_digit

    PHP : %a8() : STA [$44] : PLP : BRA .jsl

  .set_to_max
    LDA $4A : DEC : JSL cm_hex2dec
    LDA !ram_hex2dec_second_digit : ASL #4
    ORA !ram_hex2dec_third_digit

    PHP : %a8() : STA [$44] : PLP

  .jsl
    LDA [$40] : INC $40 : INC $40 : STA $0000
    BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_word:
; $0000[0x4] = indirect long jump pointer
; $3C[0x2] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
; $4A[0x2] = maximum value
{
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    LDA [$40] : INC $40 : INC $40 : STA $48
    LDA [$40] : INC $40 : INC $40 : INC : STA $4A ; INC for convenience

    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    LDA [$40] : INC $40 : INC $40 : INC $40 : INC $40 : STA $3C
    BRA .load_jsl_target

  .input_held
    INC $40 : INC $40 : LDA [$40] : INC $40 : INC $40 : STA $3C

  .load_jsl_target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left

    LDA [$44] : CLC : ADC $3C

    CMP $4A : BCS .set_to_min

    STA [$44] : BRA .jsl

  .pressed_left
    LDA [$44] : SEC : SBC $3C
    CMP $48 : BMI .set_to_max

    CMP $4A : BCS .set_to_max

    STA [$44] : BRA .jsl

  .set_to_min
    LDA $48 : STA [$44] : CLC : BRA .jsl

  .set_to_max
    LDA $4A : DEC : STA [$44] : CLC

  .jsl
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_color:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
{
    ; $44[0x3] = memory address to manipulate
    ; $00[0x3] = JSL target
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    LDA [$40] : INC $40 : INC $40 : STA $0000

    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left

    ; pressed right, max = $1F
    LDA [$44] : INC : CMP #$0020 : BCS .set_to_min
    STA [$44] : BRA .jsl

  .pressed_left
    LDA [$44] : DEC : BMI .set_to_max
    STA [$44] : BRA .jsl

  .set_to_min
    LDA #$0000 : STA [$44] : CLC : BRA .jsl

  .set_to_max
    LDA #$001F : STA [$44] : CLC

  .jsl
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_sound:
; $0000[0x4] = indirect long jump pointer
; $3C[0x2] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
; $48[0x2] = minimum value
; $4A[0x2] = maximum value
{
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    LDA [$40] : INC $40 : AND #$00FF : STA $48
    LDA [$40] : INC $40 : AND #$00FF : INC : STA $4A ; INC for convenience
    LDA [$40] : INC $40 : AND #$00FF : STA $3C

    ; 4x scroll speed if Y held
    LDA !LK_Controller_Current : AND #$4000 : BEQ +
    LDA $3C : ASL #2 : STA $3C

+   INC $40 : LDA [$40] : STA $0000

    LDA !ram_cm_controller : BIT #$4000 : BNE .jsr ; check for Y pressed
    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left

    LDA [$44] : CLC : ADC $3C
    CMP $4A : BCS .set_to_min
    PHP : %a8() : STA [$44] : PLP : BRA .end

  .pressed_left
    LDA [$44] : SEC : SBC $3C : CMP $48 : BMI .set_to_max
    CMP $4A : BCS .set_to_max
    PHP : %a8() : STA [$44] : PLP : BRA .end

  .set_to_min
    LDA $48 : PHP : %a8() : STA [$44] : PLP : CLC : BRA .end

  .set_to_max
    LDA $4A : DEC : PHP : %a8() : STA [$44] : PLP : CLC : BRA .end

  .jsr
    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
    RTS
}

execute_numfield_hex_word:
{
    ; do nothing
    RTS
}

execute_numfield_time:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; Skip past address
    INC $40 : INC $40 : INC $40

    ; $0000 = JSL target
    LDA [$40] : BEQ .end
    INC $40 : INC $40 : STA $0000

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Preload arX/Y = Argument
    ; Pre-load argument in A/X/Y and jump to routine
    LDA [$40] : TAY : TAX
    JML [$0000]

  .end
    %ai16()
    RTS
}

execute_choice:
; $0000[0x4] = indirect long jump pointer
; $38[0x2] = temp comparison
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
{
    %a16()
    LDA [$40] : INC $40 : INC $40 : STA $44
    LDA [$40] : INC $40 : STA $46

    ; Grab JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; we either increment or decrement
    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left
    LDA [$44] : INC
    BRA .bounds_check

  .pressed_left
    LDA [$44] : DEC

  .bounds_check
    TAX     ; X = new value
    LDY #$0000  ; Y will be set to max

    %a8()
  .loop_choices
    LDA [$40] : %a16() : INC $40 : %a8() : CMP.b #$FF : BEQ .loop_done

  .loop_text
    LDA [$40] : %a16() : INC $40 : %a8()
    CMP.b #$FF : BNE .loop_text
    INY : BRA .loop_choices

  .loop_done
    ; X = new value (might be out of bounds)
    ; Y = maximum + 2
    ; We need to make sure X is between 0-maximum.

    ; for convenience so we can use BCS. We do one more DEC in `.set_to_max`
    ; below, so we get the actual max.
    DEY

    %a16()
    TXA : BMI .set_to_max
    STY $38
    CMP $38 : BCS .set_to_zero

    BRA .store

  .set_to_zero
    LDA #$0000 : BRA .store

  .set_to_max
    TYA : DEC

  .store
    STA [$44]

    LDA $0000 : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA $0002
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [$44] : LDX #$0000
    JML [$0000]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_ctrl_shortcut:
; $0000[0x4] = indirect long jump pointer
; $38[0x4] = increment
; $40[0x4] = current menu item index
; $44[0x4] = memory address (long) to manipulate
{
    ; < and > should do nothing here
    ; also ignore the input held flag
    LDA !ram_cm_controller : BIT #$0301 : BNE .end

    LDA [$40] : STA $38 : INC $40 : INC $40
    LDA [$40] : STA $3A : INC $40

    LDA !ram_cm_controller : BIT #$0040 : BNE .reset_shortcut

    LDA #$0001 : STA !ram_cm_ctrl_mode
    LDA #$0000 : STA !ram_cm_ctrl_timer
    RTS

  .reset_shortcut
    LDA.w #!sram_ctrl_menu : CMP $38 : BEQ .end
;    %sfxfail()

    LDA #$0000 : STA [$38]

  .end
    %ai16()
    RTS
}

execute_controller_input:
; $0000[0x4] = indirect long jump pointer
; $40[0x4] = current menu item index
; unused, needs ram addresses from the game to function
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; store long address as short address for now
    LDA [$40] : INC $40 : INC $40 : INC $40
;    STA !ram_cm_ctrl_assign

    ; $44 = JSL target
    LDA [$40] : INC $40 : INC $40 : STA $0000

    ; Set bank of action_submenu
    ; instead of the menu we're jumping to
    LDA.l #action_submenu>>16 : STA $0002

    ; Set return address for indirect JSL
    PHK : PEA .end-1

    ; Pre-load address in A/Y and jump to routine
    LDA [$40] : TAY
    LDX #$0000
    JML [$0000]

  .end
    %ai16()
    RTS
}

cm_draw2:
; Converts a hex number into a two digit decimal number
; expects value to be drawn in A, tilemap pointer in X
{
    PHB
    STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !ram_tmp_1

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Tens digit
    LDA !ram_tmp_1 : BEQ .blanktens
    ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer,X

  .done
    PLB
    INX #4
    RTL

  .blanktens
    LDA !TILE_BLANK : STA !ram_tilemap_buffer,X
    BRA .done
}

cm_draw2_hex:
{
    PHP : %a16()
    PHB : PHK : PLB
    ; (00X0)
    LDA !ram_draw_value : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    ; (000X)
    LDA !ram_draw_value : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X
    PLB : PLP
    RTL
}

cm_draw3:
; Converts a hex number into a three digit decimal number
; expects value to be drawn in !ram_draw_value
; expects tilemap pointer in X
{
    PHB
    LDA !ram_draw_value : STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !ram_tmp_2

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !ram_tmp_2 : BEQ .blanktens
    STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_1

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Hundreds digit
    LDA !ram_tmp_1 : BEQ .blankhundreds : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer,X

  .done
    PLB
    INX #6
    RTL

  .blanktens
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X
    BRA .done

  .blankhundreds
    LDA !TILE_BLANK : STA !ram_tilemap_buffer,X
    BRA .done
}

cm_draw4:
; Converts a hex number into a four digit decimal number
; expects value to be drawn in !ram_draw_value
; expects tilemap pointer in X
{
    PHB
    LDA !ram_draw_value : STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !ram_tmp_3

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+6,X

    LDA !ram_tmp_3 : BEQ .blanktens
    STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_2

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !ram_tmp_2 : BEQ .blankhundreds
    STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_1

    ; Hundreds digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Thousands digit
    LDA !ram_tmp_1 : BEQ .blankthousands
    ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer,X

  .done
    PLB
    INX #8
    RTL

  .blanktens
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    BRA .done

  .blankhundreds
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X
    BRA .done

  .blankthousands
    LDA !TILE_BLANK : STA !ram_tilemap_buffer,X
    BRA .done
}

cm_draw4_hex:
{
    PHP : %a16()
    PHB : PHK : PLB
    ; (X000)
    LDA !ram_draw_value : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    ; (0X00)
    LDA !ram_draw_value : AND #$0F00 : XBA : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X
    ; (00X0)
    LDA !ram_draw_value : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+4,X
    ; (000X)
    LDA !ram_draw_value : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+6,X
    PLB : PLP
    RTL
}

cm_draw5:
; Converts a hex number into a five digit decimal number
; expects value to be drawn in !ram_draw_value
; expects tilemap pointer in X
{
    PHB
    LDA !ram_draw_value : STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !ram_tmp_4

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+8,X

    LDA !ram_tmp_4 : BNE +
    BRL .blanktens
+   STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_3

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+6,X

    LDA !ram_tmp_3 : BNE +
    BRL .blankhundreds
+   STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_2

    ; Hundreds digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !ram_tmp_2 : BEQ .blankthousands
    STA $004204
    %a8()
    LDA #$0A : STA $004206   ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !ram_tmp_1

    ; Thousands digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Ten thousands digit
    LDA !ram_tmp_1 : BEQ .blanktenthousands
    ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer,X

  .done
    PLB
    INX #10
    RTL

  .blanktens
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X
    STA !ram_tilemap_buffer+4,X : STA !ram_tilemap_buffer+6,X
    BRA .done

  .blankhundreds
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    BRA .done

  .blankthousands
    LDA !TILE_BLANK
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+2,X
    BRA .done

  .blanktenthousands
    LDA !TILE_BLANK : STA !ram_tilemap_buffer,X
    BRA .done
}

cm_hex2dec:
{
    STA $4204

    %a8()
    LDA #$64 : STA $4206
    PHA : PLA : PHA : PLA

    %a16()
    LDA $4214 : STA !ram_hex2dec_rest
    LDA $4216 : STA $4204

    %a8()
    LDA #$0A : STA $4206
    PHA : PLA : PHA : PLA

    %a16()
    LDA $4214 : STA !ram_hex2dec_second_digit
    LDA $4216 : STA !ram_hex2dec_third_digit
    LDA !ram_hex2dec_rest : STA $4204

    %a8()
    LDA #$0A : STA $4206
    PHA : PLA : PHA : PLA

    %a16()
    LDA $4214 : STA !ram_hex2dec_rest
    LDA $4216 : STA !ram_hex2dec_first_digit

    RTL
}

cm_dec2hex:
{
    TAY
    %a8()
    ; start with left nybble
    AND #$F0 : LSR #4 : STA $004202

    ; divide by 10
    LDA #$0A : STA $004203

    ; add right nybble
    TYA : AND #$0F : CLC
    %a16()
    ADC $004216

    RTL
}


; ----------
; Resources
; ----------

MenuGFXTileset:
incbin ../resources/LionKingMenuGFX.bin ; $400 bytes

NumberGFXTable:
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969

HexGFXTable:
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$297F, #$2977, #$2942, #$2943, #$2944, #$2945

HexToNumberGFX1:
    dw #$2960, #$2960, #$2960, #$2960, #$2960, #$2960, #$2960, #$2960, #$2960, #$2960
    dw #$2961, #$2961, #$2961, #$2961, #$2961, #$2961, #$2961, #$2961, #$2961, #$2961
    dw #$2962, #$2962, #$2962, #$2962, #$2962, #$2962, #$2962, #$2962, #$2962, #$2962
    dw #$2963, #$2963, #$2963, #$2963, #$2963, #$2963, #$2963, #$2963, #$2963, #$2963
    dw #$2964, #$2964, #$2964, #$2964, #$2964, #$2964, #$2964, #$2964, #$2964, #$2964
    dw #$2965, #$2965, #$2965, #$2965, #$2965, #$2965, #$2965, #$2965, #$2965, #$2965

HexToNumberGFX2:
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969
    dw #$2960, #$2961, #$2962, #$2963, #$2964, #$2965, #$2966, #$2967, #$2968, #$2969

ControllerInputTable:
;       Up      Down    Left    Right   L
    dw #$0800, #$0400, #$0200, #$0100, #$0020
;       A       B       X       Y       R
    dw #$0080, #$8000, #$0040, #$4000, #$0010

ControllerGFXTable:
;       Up      Down    Left    Right   L
    dw #$2973, #$2972, #$2971, #$2970, #$297D
;       A       B       X       Y       R
    dw #$297F, #$2977, #$297E, #$2976, #$297C

print pc, " menu end"
warnpc $F08000 ; mainmenu.asm
