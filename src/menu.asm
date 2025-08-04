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

%startfree(F0)

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
    ; Write $540 bytes of zeroes to !ram_tilemap_buffer
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
    LDA #$0010 : STA !DP_Maximum ; max object slots to check, there are over 83 counting Simba's
    LDA #$B217 : STA !DP_Address ; first object addr pointer
    LDA #$7E7E : STA !DP_Address+2 ; object RAM bank
    LDA #$0002 : STA !DP_Temp ; HUD elements left to find
    LDY #$000A ; offset to object variable for current health/roar on HUD

  .loopObjectSlots
    ; check the first pointer of each slot to find the HUD elements
    LDA [!DP_Address] : CMP #$0001 : BEQ .found ; health bar
    CMP #$D5D9 : BEQ .found ; roar bar
    LDA !DP_Address : CLC : ADC #$0080 : STA !DP_Address ; next object
    DEC !DP_Maximum : BNE .loopObjectSlots

  .done
    RTS

  .found
    ; store an impossible value to current health/roar to force the HUD
    ; sprite to update because it doesn't match Simba's values at $7E200x
    LDA #$0050 : STA [!DP_Address],Y
    LDA !DP_Address : CLC : ADC #$0080 : STA !DP_Address ; next enemy
    DEC !DP_Temp : BEQ .done ; HUD elements left to find
    DEC !DP_Maximum ; objects left to check, HUD elements don't always exist
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
{
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA !DP_MenuIndices
    LDA !ram_cm_menu_bank : STA !DP_MenuIndices+2 : STA !DP_CurrentMenu+2

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
    STA !DP_Palette

    ; check for special entries (header, blank line)
    LDA [!DP_MenuIndices],Y : BEQ .header
    CMP #$FFFF : BEQ .nextEntry
    ; check if tilemap bounds exceeded (only $640 available)
    CPX #$0640 : BPL .nextEntry
    STA !DP_CurrentMenu ; pointer to current menu item

    PHY : PHX

    ; Draw current menu item
    ; X = action index (numfield, toggle, etc)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : TAX
    JSR (cm_draw_action_table,X)

    PLX : PLY

  .nextEntry
    ; skip drawing blank lines
    INY #2 ; next menu item index
    BRA .loop

  .header
    ; Draw menu header
    STZ !DP_Palette
    TYA : CLC : ADC !DP_MenuIndices : INC #2 : STA !DP_CurrentMenu
    LDX #$00C6
    JSR cm_draw_text

    ; Optional footer
    TYA : CLC : ADC !DP_CurrentMenu : INC : STA !DP_CurrentMenu
    LDA [!DP_CurrentMenu] : CMP #$F007 : BNE .done

    INC !DP_CurrentMenu : INC !DP_CurrentMenu : STZ !DP_Palette
    LDX #$0606
    JSR cm_draw_text
    RTL

  .done
    DEC !DP_CurrentMenu : DEC !DP_CurrentMenu
    RTL
}

NMI_tilemap_transfer:
{
    JSL wait_for_NMI  ; Wait for next frame
    PHP : %a16() : %i8()
    LDX #$80 : STX $2115 ; vram inc mode
    LDA #$7C20 : STA $2116 ; vram word addr
    LDA #$1801 : STA $4300 ; vram write mode
    LDA.w #!ram_tilemap_buffer : STA $4302 ; source addr
    LDA.w #!ram_tilemap_buffer>>16 : STA $4304 ; source bank
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
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; grab the toggle value
    LDA [!DP_CurrentMenu] : AND #$00FF : INC !DP_CurrentMenu : STA !DP_Toggle

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    %a8()

    ; grab the value at that memory address
    LDA [!DP_Address] : CMP !DP_Toggle : BEQ .checked

    ; Off
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+0,X
    LDA.w !PALETTE_SPECIAL<<8|'F' : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+2,X
    LDA.w !PALETTE_SPECIAL<<8|'N' : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_inverted:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; grab the toggle value
    LDA [!DP_CurrentMenu] : AND #$00FF : INC !DP_CurrentMenu : STA !DP_Toggle

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    %a8()

    ; check the value at that memory address
    LDA [!DP_Address] : CMP !DP_Toggle : BNE .checked

    ; Off
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+0,X
    LDA.w !PALETTE_SPECIAL<<8|'F' : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+2,X
    LDA.w !PALETTE_SPECIAL<<8|'N' : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_bit:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; grab bitmask
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Toggle

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    ; check the value at that memory address
    LDA [!DP_Address] : AND !DP_Toggle : BNE .checked

    ; Off
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+0,X
    LDA.w !PALETTE_SPECIAL<<8|'F' : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+2,X
    LDA.w !PALETTE_SPECIAL<<8|'N' : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_toggle_bit_inverted:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; grab bitmask
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Toggle

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; Set position for ON/OFF
    TXA : CLC : ADC #$002C : TAX

    ; check the value at that memory address
    LDA [!DP_Address] : AND !DP_Toggle : BEQ .checked

    ; Off
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+0,X
    LDA.w !PALETTE_SPECIAL<<8|'F' : STA !ram_tilemap_buffer+2,X : STA !ram_tilemap_buffer+4,X
    RTS

  .checked
    ; On
    %a16()
    LDA.w !PALETTE_SPECIAL<<8|'O' : STA !ram_tilemap_buffer+2,X
    LDA.w !PALETTE_SPECIAL<<8|'N' : STA !ram_tilemap_buffer+4,X
    RTS
}

draw_jsl_submenu:
draw_jsl:
{
    ; skip JSL address
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; skip argument
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; draw text normally
    %item_index_to_vram_index()
    JSR cm_draw_text
    RTS
}

draw_numfield_8bit:
draw_numfield:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip bounds and increment values
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002C : TAX

    LDA [!DP_Address] : AND #$00FF : JSR cm_hex2dec

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                             STA !ram_tilemap_buffer+2,X
                             STA !ram_tilemap_buffer+4,X

    ; Set palette
    %a8()
    LDA.b !PALETTE_SPECIAL : STA !DP_Palette+1
    LDA.b #'0' : STA !DP_Palette ; points to row of number tiles in VRAM

    ; Draw numbers
    %a16()
    ; ones
    LDA !DP_ThirdDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+4,X

    ; tens
    LDA !DP_SecondDigit : ORA !DP_FirstDigit : BEQ .done
    LDA !DP_SecondDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+2,X

    LDA !DP_FirstDigit : BEQ .done
    CLC : ADC !DP_Palette : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_decimal:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip bounds and increment values
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

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
    LDA.b !PALETTE_SPECIAL : STA !DP_Palette+1
    LDA.b #'0' : STA !DP_Palette ; points to row of number tiles in VRAM

    LDA [!DP_Address] : TAY
    %a16()

    ; Draw numbers
    ; ones
    AND #$000F : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+2,X

    ; tens
    TYA : AND #$00F0 : BEQ .done
    LSR #4 : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_word:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip bounds and increment values
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002A : TAX

    LDA [!DP_Address] : JSR cm_hex2dec

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                             STA !ram_tilemap_buffer+2,X
                             STA !ram_tilemap_buffer+4,X
                             STA !ram_tilemap_buffer+6,X

    ; Set palette and tile row
    %a8()
    LDA.b !PALETTE_SPECIAL : STA !DP_Palette+1
    LDA.b #'0' : STA !DP_Palette ; points to row of number tiles

    ; Draw numbers, which are tiles 60-69 in VRAM
    %a16()
    ; ones
    LDA !DP_ThirdDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+6,X

    ; tens
    LDA !DP_SecondDigit : ORA !DP_FirstDigit
    ORA !DP_Temp : BEQ .done
    LDA !DP_SecondDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+4,X

    LDA !DP_FirstDigit : ORA !DP_Temp : BEQ .done
    LDA !DP_FirstDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+2,X

    LDA !DP_Temp : BEQ .done
    CLC : ADC !DP_Palette : STA !ram_tilemap_buffer,X

  .done
    RTS
}

draw_numfield_time:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip JSL target
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; skip JSL argument
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

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
    LDA [!DP_Address],Y : CMP #$10 : BPL .done
    STA !DP_Minutes : DEY
    LDA [!DP_Address],Y : STA !DP_Seconds : DEY
    LDA [!DP_Address],Y : STA !DP_Frames
    %a16()

    ; draw minutes digit
    LDA !DP_Minutes : AND #$000F : ASL : TAY
    INX #2
    LDA.w HexToNumberGFX2,Y : STA !ram_tilemap_buffer,X
    INX #2

    ; draw colons
    LDA !TILE_COLON
    STA !ram_tilemap_buffer,X : STA !ram_tilemap_buffer+6,X
    INX #2

    ; draw seconds digits
    LDA !DP_Seconds : AND #$00FF : JSL cm_dec2hex
    ASL : TAY
    LDA.w HexToNumberGFX1,Y : STA !ram_tilemap_buffer,X
    INX #2
    LDA.w HexToNumberGFX2,Y : STA !ram_tilemap_buffer,X
    INX #4 ; skip a tile for the colon

    ; draw frames digits
    LDA !DP_Frames : AND #$00FF : JSL cm_dec2hex
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
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip bounds and increment values
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002E : TAX

    ; load 8bit value from address
    LDA [!DP_Address] : AND #$00FF : STA !DP_Value

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                             STA !ram_tilemap_buffer+2,X

    ; Set data bank for HexGFXTable
    PHB
    LDA.w #HexGFXTable>>8&$FF00 : PHA
    PLB : PLB

    ; Draw numbers
    ; (00X0)
    LDA !DP_Value : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    
    ; (000X)
    LDA !DP_Value : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X

    PLB
    RTS
}

draw_numfield_color:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; increment past JSL
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002E : TAX

    ; load 8bit value from address
    LDA [!DP_Address] : AND #$00FF : STA !DP_Value

    ; Clear out the area (black tile)
    LDA !ram_cm_blank_tile : STA !ram_tilemap_buffer+0,X
                             STA !ram_tilemap_buffer+2,X

    ; Set data bank for HexGFXTable
    PHB
    LDA.w #HexGFXTable>>8&$FF00 : PHA
    PLB : PLB

    ; Draw numbers
    ; (00X0)
    LDA !DP_Value : AND #$001E : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X

    ; (000X)
    LDA !DP_Value : AND #$0001 : ASL #4 : STA !DP_Temp
    LDA !DP_Value : AND #$001C : LSR : CLC : ADC !DP_Temp : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X

    PLB
    RTS
}

draw_numfield_hex_word:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip bitmask and JSL address
    INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the number
    TXA : CLC : ADC #$002A : TAX

    ; load the value
    LDA [!DP_Address] : STA !DP_Value

    ; set data bank for number table
    PHB : PEA.w NumberGFXTable>>8 : PLB : PLB

    ; Draw numbers
    ; (X000)
    LDA !DP_Value : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    ; (0X00)
    LDA !DP_Value : AND #$0F00 : XBA : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X
    ; (00X0)
    LDA !DP_Value : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+4,X
    ; (000X)
    LDA !DP_Value : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+6,X

    ; overwrite palette bytes
    %a8()
    LDA.b !PALETTE_SPECIAL
    STA !ram_tilemap_buffer+1,X : STA !ram_tilemap_buffer+3,X
    STA !ram_tilemap_buffer+5,X : STA !ram_tilemap_buffer+7,X
    %a16()

    PLB
    RTS
}

draw_choice:
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip JSL target
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text first
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for choice
    TXA : CLC : ADC #$001C : TAX

    ; use address as index
    LDA [!DP_Address] : TAY

    ; find the correct text that should be drawn (the selected choice)
    ; read through the text and DEY until zero to find selected choice
    INY #2 ; skip the first text that we already drew
  .loop_choices
    DEY : BEQ .found

  .loop_text
    ; text is 8bit, pointer is 16bit :( 
    LDA [!DP_CurrentMenu] : %a16() : INC !DP_CurrentMenu : %a8()
    CMP #$FF : BEQ .loop_choices
    BRA .loop_text

  .found
    %a16()
    JSR cm_draw_text

    %a16()
    RTS
}

draw_ctrl_shortcut:
{
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    %item_index_to_vram_index()
    PHX
    JSR cm_draw_text
    PLA : CLC : ADC #$0022 : TAX

    LDA [!DP_Address]
    JSR menu_ctrl_input_display

    RTS
}

draw_controller_input:
; unused, needs ram addresses from the game to function
{
    ; grab the memory address (long)
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : INC !DP_CurrentMenu : STA !DP_Address
;    STA !ram_cm_ctrl_assign
    LDA [!DP_CurrentMenu] : INC !DP_CurrentMenu : STA !DP_Address+2

    ; skip JSL target
;    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; skip JSL argument
    INC !DP_CurrentMenu : INC !DP_CurrentMenu

    ; Draw the text
    %item_index_to_vram_index()
    PHX : JSR cm_draw_text : PLX

    ; set position for the input
    TXA : CLC : ADC #$0020 : TAX

    LDA (!DP_Address) : AND #$E0F0 : BEQ .unbound

    ; determine which input to draw, using Y to refresh A
    TAY : AND !CTRL_A : BEQ + : LDY #$0000 : BRA .draw
+   TYA : AND !CTRL_B : BEQ + : LDY #$0002 : BRA .draw
+   TYA : AND !CTRL_X : BEQ + : LDY #$0004 : BRA .draw
+   TYA : AND !CTRL_Y : BEQ + : LDY #$0006 : BRA .draw
+   TYA : AND !CTRL_L : BEQ + : LDY #$0008 : BRA .draw
+   TYA : AND !CTRL_R : BEQ + : LDY #$000A : BRA .draw
+   TYA : AND !CTRL_SELECT : BEQ .unbound : LDY #$000C

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
{
    %a8()
    LDY #$0000
    ; $FF = terminator
    LDA [!DP_CurrentMenu],Y : INY : CMP #$FF : BEQ .end

    ; Special palette shouldn't be "selected"
    CMP.b !PALETTE_SPECIAL : BNE +
    STA !DP_Palette : BRA .loop

    ; ORA with palette info
+   ORA !DP_Palette : STA !DP_Palette

  .loop
    LDA [!DP_CurrentMenu],Y : CMP #$FF : BEQ .end ; check if terminator
    STA !ram_tilemap_buffer,X : INX               ; store tile
    LDA !DP_Palette : STA !ram_tilemap_buffer,X   ; store palette
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
; X = pointer to tilemap area (STA !ram_tilemap_buffer,X)
; A = Controller word
{
    JSR menu_ctrl_clear_input_display

    XBA
    LDY #$0000
  .loop
    PHA
    BIT #$0001 : BEQ .no_draw

    TYA : CLC : ADC #$0070
    XBA : ORA !DP_Palette : XBA
    STA !ram_tilemap_buffer,X : INX #2

  .no_draw
    PLA
    INY
    LSR : BNE .loop

  .done
    RTS
}


menu_ctrl_clear_input_display:
; X = pointer to tilemap area
{
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
    JSL wait_for_NMI ; Wait for next frame
    %a8()
    LDA #$0F : STA $0F2100 ; ensure full brightness
    %a16()

    LDA !ram_cm_leave : BEQ +
    RTS ; Exit menu loop

    ; check if configuring controller shortcuts or editing numbers
+   LDA !ram_cm_ctrl_mode : BMI .singleDigitEditing : BEQ +
    JSR cm_ctrl_mode
    BRA cm_loop

  .singleDigitEditing
    JSR cm_edit_digits
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
{
    JSL ReadControllerInputs_long
    LDA !LK_Controller_Current

    ; set palette
    %a8() : LDA.b !PALETTE_SPECIAL : STA !DP_Palette : %a16()

    LDA !LK_Controller_Current : BEQ .clear_and_draw
    CMP !ram_cm_ctrl_last_input : BNE .clear_and_draw

    ; Holding an input for more than one second
    LDA !ram_cm_ctrl_timer : INC : STA !ram_cm_ctrl_timer : CMP.w #0060 : BNE .next_frame

    ; disallow inputs that match the menu shortcut
    LDA !DP_Value : CMP.w #!sram_ctrl_menu : BEQ .store
    LDA !LK_Controller_Current : CMP !sram_ctrl_menu : BNE .store
;    %sfxfail()
    ; set cursor position to 0 (menu shortcut)
    LDX.w !ram_cm_stack_index
    LDA #$0000 : STA !ram_cm_cursor_stack,X
    BRA .exit

  .store
    LDA !LK_Controller_Current : STA [!DP_Value]
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

cm_edit_digits:
{
    ; hex or decimal
    LDA !ram_cm_ctrl_mode : CMP #$8001 : BEQ .decimal_mode

    ; check for A, B, and D-pad
    JSR cm_get_inputs : STA !ram_cm_controller
    AND #$8F80 : BEQ .redraw
    BIT !CTRL_HORIZ : BNE .selecting
    BIT !CTRL_VERT : BNE .editing
    BIT #$8080 : BEQ .redraw

    ; exit if A or B pressed
    ; skip if JSL target is zero
    LDA !DP_JSLTarget : BEQ .end
    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1
    ; addr in A
    LDA [!DP_DigitAddress] : LDX #$0000
    JML.w [!DP_JSLTarget]

  .end
    %ai16()
    LDA #$0000 : STA !ram_cm_ctrl_mode
;    %sfxconfirm()
    JSL cm_draw
    RTS

  .decimal_mode
    JMP cm_edit_decimal_digits

  .selecting
;    %sfxmove()
    ; determine which direction was pressed
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .left
    ; inc/dec horizontal cursor index
    LDA !ram_cm_horizontal_cursor : DEC : AND #$0003 : STA !ram_cm_horizontal_cursor
    BRA .redraw
  .left
    LDA !ram_cm_horizontal_cursor : INC : AND #$0003 : STA !ram_cm_horizontal_cursor
  .redraw
    ; redraw numbers so selected digit is highlighted
    LDX.w !ram_cm_stack_index
    LDY.w !ram_cm_cursor_stack,X
    %item_index_to_vram_index()
    TXA : CLC : ADC #$002A : TAX
    LDA [!DP_DigitAddress]
    JMP cm_draw4_editing ; and return from there

  .editing
    ; use horizontal cursor index to ADC/SBC
    LDA !ram_cm_horizontal_cursor : ASL : TAX
    ; determine which direction was pressed
    LDA !LK_Controller_Current : BIT !CTRL_UP : BNE +
    TXA : CLC : ADC #$0008 : TAX

    ; subroutine to inc/dec digit
+   LDA [!DP_DigitAddress] : JSR (cm_SingleDigitEdit,X)
    ; returns full value with selected digit cleared
    ; combine with modified digit and cap with bitmask in !DP_DigitMaximum
    ORA !DP_DigitValue : AND !DP_DigitMaximum : STA [!DP_DigitAddress]
;    %sfxnumber()

    ; redraw numbers
    LDX.w !ram_cm_stack_index : LDA !ram_cm_cursor_stack,X : TAY
    %item_index_to_vram_index()
    TXA : CLC : ADC #$002A : TAX
    LDA [!DP_DigitAddress]

    ; fallthrough to cm_draw4_editing and return from there
}

cm_draw4_editing:
{
    PHB
    PHK : PLB

    ; (X000)
    STA !DP_Value : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer,X
    ; (0X00)
    LDA !DP_Value : AND #$0F00 : XBA : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+2,X
    ; (00X0)
    LDA !DP_Value : AND #$00F0 : LSR #3 : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+4,X
    ; (000X)
    LDA !DP_Value : AND #$000F : ASL : TAY
    LDA.w HexGFXTable,Y : STA !ram_tilemap_buffer+6,X

    ; set palette bytes to unselected
    %a8()
    LDA.b !PALETTE_HEADER
    STA !ram_tilemap_buffer+1,X : STA !ram_tilemap_buffer+3,X
    STA !ram_tilemap_buffer+5,X : STA !ram_tilemap_buffer+7,X

    ; highlight selected digit only
    LDA !ram_cm_horizontal_cursor : BEQ .ones
    DEC : BEQ .tens
    DEC : BEQ .hundreds
    ; thousands $X000
    LDA.b !PALETTE_SELECTED : STA !ram_tilemap_buffer+1,X
    BRA .done
  .hundreds ; $0X00
    LDA.b !PALETTE_SELECTED : STA !ram_tilemap_buffer+3,X
    BRA .done
  .tens ; $00X0
    LDA.b !PALETTE_SELECTED : STA !ram_tilemap_buffer+5,X
    BRA .done
  .ones ; $000X
    LDA.b !PALETTE_SELECTED : STA !ram_tilemap_buffer+7,X

  .done
    %a16()
    PLB
    JSL NMI_tilemap_transfer
    RTS
}

cm_SingleDigitEdit:
    dw #cm_SDE_add_ones
    dw #cm_SDE_add_tens
    dw #cm_SDE_add_hundreds
    dw #cm_SDE_add_thousands
    dw #cm_SDE_sub_ones
    dw #cm_SDE_sub_tens
    dw #cm_SDE_sub_hundreds
    dw #cm_SDE_sub_thousands

    %SDE_add(ones, #$0001, #$000F, #$FFF0)
    %SDE_add(tens, #$0010, #$00F0, #$FF0F)
    %SDE_add(hundreds, #$0100, #$0F00, #$F0FF)
    %SDE_add(thousands, #$1000, #$F000, #$0FFF)
    %SDE_sub(ones, #$0001, #$000F, #$FFF0)
    %SDE_sub(tens, #$0010, #$00F0, #$FF0F)
    %SDE_sub(hundreds, #$0100, #$0F00, #$F0FF)
    %SDE_sub(thousands, #$1000, #$F000, #$0FFF)

cm_edit_decimal_digits:
{
    ; check for A, B, and D-pad
    JSR cm_get_inputs : STA !ram_cm_controller
    AND #$8F80 : BEQ .redraw
    BIT !CTRL_HORIZ : BNE .selecting
    BIT !CTRL_VERT : BNE .editing
    BIT #$8080 : BEQ .redraw

    ; exit if A or B pressed
    BRL .exit

  .selecting
;    %sfxmove()
    ; determine which direction was pressed
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .left
    ; inc/dec horizontal cursor index
    LDA !ram_cm_horizontal_cursor : DEC : AND #$0003 : STA !ram_cm_horizontal_cursor
    CMP #$0003 : BNE .redraw
    ; is editing thousands digit allowed?
    LDA !DP_DigitMaximum : CMP #1000 : BPL .redraw
    ; limit cursor to 3 positions (0-2)
    LDA #$0002 : STA !ram_cm_horizontal_cursor
    BRL .draw
  .left
    LDA !ram_cm_horizontal_cursor : INC : AND #$0003 : STA !ram_cm_horizontal_cursor
    CMP #$0003 : BNE .redraw
    ; is editing thousands digit allowed?
    LDA !DP_DigitMaximum : CMP #1000 : BPL .redraw
    ; limit cursor to 3 positions (0-2)
    LDA #$0000 : STA !ram_cm_horizontal_cursor

  .redraw
    BRL .draw

  .editing
    ; convert value to decimal
    LDA !DP_DigitValue : JSR cm_hex2dec

    ; determine which digit to edit
    LDA !ram_cm_horizontal_cursor : BEQ .ones
    DEC : BEQ .tens
    DEC : BEQ .hundreds

    %SDE_dec(thousands, !DP_Temp)
    BRA .dec2hex
  .hundreds
    %SDE_dec(hundreds, !DP_FirstDigit)
    BRA .dec2hex
  .tens
    %SDE_dec(tens, !DP_SecondDigit)
    BRA .dec2hex
  .ones
    %SDE_dec(ones, !DP_ThirdDigit)

  .dec2hex
;    %sfxnumber()
    JSR cm_reverse_hex2dec

  .draw
    ; convert value to decimal
    LDA !DP_DigitValue : JSR cm_hex2dec

    ; get tilemap address
    LDX.w !ram_cm_stack_index : LDA !ram_cm_cursor_stack,X : TAY
    %item_index_to_vram_index()
    TXA : CLC : ADC #$002A : TAX

    ; is editing thousands digit allowed?
    LDA.w !PALETTE_HEADER<<8|'0'
    LDY !DP_DigitMaximum : CPY #1000 : BMI +

    ; start with zero tiles
    STA !ram_tilemap_buffer+0,X
+   STA !ram_tilemap_buffer+2,X
    STA !ram_tilemap_buffer+4,X
    STA !ram_tilemap_buffer+6,X

    ; set palette and default zero tile
    STA !DP_Palette

    ; Draw numbers
    ; ones
    LDA !DP_ThirdDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+6,X
    ; tens
    LDA !DP_SecondDigit : ORA !DP_FirstDigit
    ORA !DP_Temp : BEQ .highlighting
    LDA !DP_SecondDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+4,X
    ; hundreds
    LDA !DP_FirstDigit : ORA !DP_Temp : BEQ .highlighting
    LDA !DP_FirstDigit : CLC : ADC !DP_Palette : STA !ram_tilemap_buffer+2,X
    ; thousands
    LDA !DP_Temp : BEQ .highlighting
    CLC : ADC !DP_Palette : STA !ram_tilemap_buffer,X

  .highlighting
    ; highlight the selected tile
    LDA !ram_cm_horizontal_cursor : BEQ .highlight_ones
    DEC : BEQ .highlight_tens
    DEC : BEQ .highlight_hundreds
    ; thousands $X000
    BRA .highlight
  .highlight_hundreds
    INX #2 : BRA .highlight
  .highlight_tens
    INX #4 : BRA .highlight
  .highlight_ones
    TXA : CLC : ADC #$0006 : TAX
  .highlight
    ; number tiles are 60-69
!PALETTE_SELECTED = #$2D
    LDA !ram_tilemap_buffer,X : ORA.w !PALETTE_SELECTED<<8|'0' : STA !ram_tilemap_buffer,X

    JSL NMI_tilemap_transfer
    RTS

  .exit
    ; check if value is inbounds
    LDA !DP_DigitValue : CMP !DP_DigitMaximum : BMI .check_minimum
    LDA !DP_DigitMaximum : DEC : BRA + ; was max+1 for convenience
  .check_minimum
    CMP !DP_DigitMinimum : BPL +
    LDA !DP_DigitMinimum
+   STA [!DP_DigitAddress]

    ; skip if JSL target is zero
    LDA !DP_JSLTarget : BEQ .end
    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1
    ; addr in A
    LDA [!DP_DigitAddress]
    JML.w [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxconfirm()
    LDA #$0000 : STA !ram_cm_ctrl_mode
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
    LDA.l #MainMenu>>16 ; Reset submenu bank when back at main menu
    STA !ram_cm_menu_bank
    LDA #$0000 : STA !ram_mem_editor_active

  .end
;    %sfxgoback()
    RTL
}

cm_calculate_max:
; Determines the cursor's max/last position
{
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA !DP_MenuIndices
    LDA !ram_cm_menu_bank : STA !DP_MenuIndices+2

    LDX #$0000
  .loop
    LDA [!DP_MenuIndices] : BEQ .done
    INC !DP_MenuIndices : INC !DP_MenuIndices
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
    LDA !LK_Controller_Current : AND #$4F00 : ORA !CTRL_HELD
    RTS

  .noinput
    ; return zero if not a new input or held DPAD input
    LDA #$0000
    RTS
}

cm_move:
{
    STA !DP_Temp
    LDX.w !ram_cm_stack_index
    CLC : ADC !ram_cm_cursor_stack,X : BPL .positive
    LDA !ram_cm_cursor_max : DEC #2 : BRA .inBounds

  .positive
    CMP !ram_cm_cursor_max : BNE .inBounds
    LDA #$0000

  .inBounds
    STA !ram_cm_cursor_stack,X : TAY

    LDA !ram_cm_menu_stack,X : STA !DP_MenuIndices
    LDA !ram_cm_menu_bank : STA !DP_MenuIndices+2

    ; check for blank menu line ($FFFF)
    LDA [!DP_MenuIndices],Y : CMP #$FFFF : BNE .end

    LDA !DP_Temp : BRA cm_move

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
    STA !DP_MenuIndices+2 : STA !DP_CurrentMenu+2

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
{
    LDX.w !ram_cm_stack_index
    LDA !ram_cm_menu_stack,X : STA !DP_MenuIndices
    LDA !ram_cm_menu_bank : STA !DP_MenuIndices+2
    LDA !ram_cm_cursor_stack,X : TAY
    LDA [!DP_MenuIndices],Y : STA !DP_MenuIndices

    ; Load and increment past the action index
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : TAX

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
{
    ; Grab address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    ; Load which bit(s) to toggle, 8-bit only
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Toggle

    ; Grab JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; On or Off?
    %a8()
    LDA [!DP_Address] : CMP !DP_Toggle : BEQ .toggleOff

    ; Store toggle value to address
    LDA !DP_Toggle : STA [!DP_Address]
    BRA .jsl

  .toggleOff
    ; Clear memory address
    LDA #$00 : STA [!DP_Address]

  .jsl
    ; Check if JSL target exists
    %a16()
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_toggle_bit:
{
    ; Load the address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    ; Load which bit(s) to toggle
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Toggle

    ; Load JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Toggle the bit
    LDA [!DP_Address] : EOR !DP_Toggle : STA [!DP_Address]

    ; Check if JSL target exists
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_jsl_submenu:
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Set bank of action_submenu
    ; instead of the menu we're jumping to
    LDA.l #action_submenu>>16 : STA !DP_JSLTarget+2

    ; Set return address for indirect JSL
    PHK : PEA .end-1

    ; Y = Argument
    LDA [!DP_MenuIndices] : TAY

    ; Jump to routine
    LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
    RTS
}

execute_jsl:
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Y = Argument
    LDA [!DP_MenuIndices] : TAY

    ; Jump to routine
    LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
    RTS
}

execute_numfield_hex:
execute_numfield:
{
    ; Load memory address to manipulate
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2 ; bank

    ; Load minimum and maximum values
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Minimum
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : INC : STA !DP_Maximum ; INC for convenience

    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    ; Load the normal increment value
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment
    BRA .load_jsl_target

  .input_held
    ; Load the faster increment value
    INC !DP_MenuIndices : LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment

  .load_jsl_target
    ; Load pointer for routine to run next
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .pressed_left
    ; pressed right, inc
    LDA [!DP_Address] : CLC : ADC !DP_Increment
    CMP !DP_Maximum : BCS .set_to_min
    PHP : %a8() : STA [!DP_Address] : PLP : BRA .jsl

  .pressed_left ; dec
    LDA [!DP_Address] : SEC : SBC !DP_Increment
    CMP !DP_Minimum : BMI .set_to_max
    CMP !DP_Maximum : BCS .set_to_max
    PHP : %a8() : STA [!DP_Address] : PLP : BRA .jsl

  .set_to_min
    LDA !DP_Minimum : PHP : %a8() : STA [!DP_Address] : PLP : CLC : BRA .jsl

  .set_to_max
    LDA !DP_Maximum : DEC : PHP : %a8() : STA [!DP_Address] : PLP : CLC

  .jsl
    ; Check if JSL target exists
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_8bit:
{
    ; Load memory address to manipulate
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    ; Load min/max values
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Minimum
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : INC : STA !DP_Maximum ; INC for convenience

    ; Check if input held flag is set
    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    ; Use normal increment value
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment
    BRA .load_jsl_target

  .input_held
    ; Use the faster increment value
    INC !DP_MenuIndices : LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment

  .load_jsl_target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Check direction input
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .pressed_left

    ; Pressed right, inc
    LDA [!DP_Address] : AND #$00FF : CLC : ADC !DP_Increment

    ; Check if above maximum
    CMP !DP_Maximum : BCS .set_to_min

    ; Store 8-bit value
    PHP : %a8() : STA [!DP_Address] : PLP
    BRA .jsl

  .pressed_left ; dec
    LDA [!DP_Address] : AND #$00FF : SEC : SBC !DP_Increment
    ; Check if below minimum
    CMP !DP_Minimum : BMI .set_to_max

    ; Check if above maximum
    CMP !DP_Maximum : BCS .set_to_min

    ; Store 8-bit value
    PHP : %a8() : STA [!DP_Address] : PLP
    BRA .jsl

  .set_to_min
    LDA !DP_Minimum
    PHP : %a8() : STA [!DP_Address] : PLP
    CLC : BRA .jsl

  .set_to_max
    LDA !DP_Maximum : DEC
    PHP : %a8() : STA [!DP_Address] : PLP
    CLC

  .jsl
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load 8-bit address in A and jump to routine
    LDA [!DP_Address] : AND #$00FF
    LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_decimal:
{
    ; Load memory address to manipulate
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Minimum
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : INC : STA !DP_Maximum ; INC for convenience

    LDA !ram_cm_controller : BIT #$0001 : BNE .input_held
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment
    BRA .inc_or_dec

  .input_held
    INC !DP_MenuIndices : LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment

  .inc_or_dec
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .pressed_left
    LDA [!DP_Address] : AND #$00FF : JSL cm_dec2hex
    
    CLC : ADC !DP_Increment
    CMP !DP_Maximum : BCS .set_to_min

    JSR cm_hex2dec
    LDA !DP_SecondDigit : ASL #4
    ORA !DP_ThirdDigit

    PHP : %a8() : STA [!DP_Address] : PLP : BRA .jsl

  .pressed_left
    LDA [!DP_Address] : AND #$00FF : JSL cm_dec2hex
    
    SEC : SBC !DP_Increment : CMP !DP_Minimum : BMI .set_to_max
    CMP !DP_Maximum : BCS .set_to_max

    JSR cm_hex2dec
    LDA !DP_SecondDigit : ASL #4
    ORA !DP_ThirdDigit

    PHP : %a8() : STA [!DP_Address] : PLP : BRA .jsl

  .set_to_min
    LDA !DP_Minimum : JSR cm_hex2dec
    LDA !DP_SecondDigit : ASL #4
    ORA !DP_ThirdDigit

    PHP : %a8() : STA [!DP_Address] : PLP : BRA .jsl

  .set_to_max
    LDA !DP_Maximum : DEC : JSR cm_hex2dec
    LDA !DP_SecondDigit : ASL #4
    ORA !DP_ThirdDigit

    PHP : %a8() : STA [!DP_Address] : PLP

  .jsl
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget
    BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_word:
{
    ; grab the memory address (long)
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_DigitAddress
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_DigitAddress+2

    ; grab minimum (!DP_DigitMinimum) and maximum (!DP_DigitMaximum) values
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_DigitMinimum
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : INC : STA !DP_DigitMaximum ; INC for convenience

    ; grab normal increment
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Increment
    ; check if fast scroll button is held
    LDA !LK_Controller_Current : AND !CTRL_Y : BEQ +
    ; 4x scroll speed if held
    LDA !DP_Increment : ASL #2 : STA !DP_Increment

    ; check for held inputs
+   LDA !ram_cm_controller : BIT !CTRL_HELD : BEQ .incPastFastValue
    ; input held, grab faster increment
    LDA [!DP_MenuIndices] : AND #$00FF : STA !DP_Increment
    ; keep normal increment and skip past fast value
  .incPastFastValue
    INC !DP_MenuIndices : INC !DP_MenuIndices

    LDA [!DP_MenuIndices] : STA !DP_JSLTarget

    ; left/right = increment, A/X/Y = SDE mode
    LDA !ram_cm_controller : BIT !CTRL_HORIZ : BEQ .singleDigitEditing

    ; check direction held
    BIT #$0200 : BNE .pressed_left
    ; pressed right, inc
    LDA [!DP_DigitAddress] : CLC : ADC !DP_Increment
    CMP !DP_DigitMaximum : BCS .set_to_min
    STA [!DP_DigitAddress] : BRA .jsl

  .pressed_left ; dec
    LDA [!DP_DigitAddress] : SEC : SBC !DP_Increment
    CMP !DP_DigitMinimum : BMI .set_to_max
    CMP !DP_DigitMaximum : BCS .set_to_max
    STA [!DP_DigitAddress] : BRA .jsl

  .set_to_min
    LDA !DP_DigitMinimum : STA [!DP_DigitAddress] : BRA .jsl

  .set_to_max
    LDA !DP_DigitMaximum : DEC : STA [!DP_DigitAddress]

  .jsl
    ; skip if JSL target is zero
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; addr in A
    LDA [!DP_Address] : LDX #$0000
    JML.w [!DP_JSLTarget]

  .singleDigitEditing
    ; check if maximum requires 3 digits or 4
    LDA !DP_DigitMinimum : CMP #1000 : BPL +
    LDA !ram_cm_horizontal_cursor : CMP #$0003 : BNE +
    LDA #$0002 : STA !ram_cm_horizontal_cursor

+   LDA [!DP_DigitAddress] : STA !DP_DigitValue
    LDA #$8001 : STA !ram_cm_ctrl_mode

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_color:
{
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    LDA !ram_cm_controller : BIT #$0200 : BNE .pressed_left

    ; pressed right, max = $1F
    LDA [!DP_Address] : INC : CMP #$0020 : BCS .set_to_min
    STA [!DP_Address] : BRA .jsl

  .pressed_left
    LDA [!DP_Address] : DEC : BMI .set_to_max
    STA [!DP_Address] : BRA .jsl

  .set_to_min
    LDA #$0000 : STA [!DP_Address] : CLC : BRA .jsl

  .set_to_max
    LDA #$001F : STA [!DP_Address] : CLC

  .jsl
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxnumber()
    RTS
}

execute_numfield_sound:
{
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Minimum
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : INC : STA !DP_Maximum ; INC for convenience
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : AND #$00FF : STA !DP_Increment

    ; 4x scroll speed if Y held
    LDA !LK_Controller_Current : AND !CTRL_Y : BEQ +
    LDA !DP_Increment : ASL #2 : STA !DP_Increment

+   INC !DP_MenuIndices : LDA [!DP_MenuIndices] : STA !DP_JSLTarget

    LDA !ram_cm_controller : BIT !CTRL_Y : BNE .jsr
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .pressed_left

    LDA [!DP_Address] : CLC : ADC !DP_Increment
    CMP !DP_Maximum : BCS .set_to_min
    PHP : %a8() : STA [!DP_Address] : PLP : BRA .end

  .pressed_left
    LDA [!DP_Address] : SEC : SBC !DP_Increment : CMP !DP_Minimum : BMI .set_to_max
    CMP !DP_Maximum : BCS .set_to_max
    PHP : %a8() : STA [!DP_Address] : PLP : BRA .end

  .set_to_min
    LDA !DP_Minimum : PHP : %a8() : STA [!DP_Address] : PLP : CLC : BRA .end

  .set_to_max
    LDA !DP_Maximum : DEC : PHP : %a8() : STA [!DP_Address] : PLP : CLC : BRA .end

  .jsr
    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
    RTS
}

execute_numfield_hex_word:
{
    ; disallow editing if "Screenshot To Share Colors" menu
    LDA !ram_cm_stack_index : TAX
    LDA !ram_cm_menu_stack,X : CMP.w #PalettesDisplayMenu : BEQ .done

    ; grab the memory address (long)
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_DigitAddress
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_DigitAddress+2

    ; grab maximum bitmask
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_DigitMaximum

    ; grab JSL address
    LDA [!DP_MenuIndices] : STA !DP_JSLTarget

    ; enable single digit numfield editing
    LDA #$FFFF : STA !ram_cm_ctrl_mode
;    %sfxnumber()

  .done
    RTS
}

execute_numfield_time:
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; Skip past address
    INC !DP_MenuIndices : INC !DP_MenuIndices : INC !DP_MenuIndices

    ; JSL target
    LDA [!DP_MenuIndices] : BEQ .end
    INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load argument in A/X/Y and jump to routine
    LDA [!DP_MenuIndices] : TAY : TAX
    JML [!DP_JSLTarget]

  .end
    %ai16()
    RTS
}

execute_choice:
{
    %a16()
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_Address
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : STA !DP_Address+2

    ; Grab JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; we either increment or decrement
    LDA !ram_cm_controller : BIT !CTRL_LEFT : BNE .pressed_left
    LDA [!DP_Address] : INC
    BRA .bounds_check

  .pressed_left
    LDA [!DP_Address] : DEC

  .bounds_check
    TAX ; X = new value
    LDY #$0000 ; Y will be set to max

    %a8()
  .loop_choices
    LDA [!DP_MenuIndices] : %a16() : INC !DP_MenuIndices : %a8() : CMP.b #$FF : BEQ .loop_done

  .loop_text
    LDA [!DP_MenuIndices] : %a16() : INC !DP_MenuIndices : %a8()
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
    STY !DP_Temp
    CMP !DP_Temp : BCS .set_to_zero

    BRA .store

  .set_to_zero
    LDA #$0000 : BRA .store

  .set_to_max
    TYA : DEC

  .store
    STA [!DP_Address]

    LDA !DP_JSLTarget : BEQ .end

    ; Set return address for indirect JSL
    LDA !ram_cm_menu_bank : STA !DP_JSLTarget+2
    PHK : PEA .end-1

    ; Pre-load address in A and jump to routine
    LDA [!DP_Address] : LDX #$0000
    JML [!DP_JSLTarget]

  .end
    %ai16()
;    %sfxtoggle()
    RTS
}

execute_ctrl_shortcut:
{
    ; < and > should do nothing here
    ; also ignore the input held flag
    LDA !ram_cm_controller : BIT #$0301 : BNE .end

    LDA [!DP_MenuIndices] : STA !DP_Value : INC !DP_MenuIndices : INC !DP_MenuIndices
    LDA [!DP_MenuIndices] : STA !DP_Value+2 : INC !DP_MenuIndices

    LDA !ram_cm_controller : BIT #$0040 : BNE .reset_shortcut

    LDA #$0001 : STA !ram_cm_ctrl_mode
    LDA #$0000 : STA !ram_cm_ctrl_timer
    RTS

  .reset_shortcut
    LDA.w #!sram_ctrl_menu : CMP !DP_Value : BEQ .end
;    %sfxfail()

    LDA #$0000 : STA [!DP_Value]

  .end
    %ai16()
    RTS
}

execute_controller_input:
; unused, needs ram addresses from the game to function
{
    ; <, > and X should do nothing here
    ; also ignore input held flag
    LDA !ram_cm_controller : BIT #$0341 : BNE .end

    ; store long address as short address for now
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : INC !DP_MenuIndices
;    STA !ram_cm_ctrl_assign

    ; $44 = JSL target
    LDA [!DP_MenuIndices] : INC !DP_MenuIndices : INC !DP_MenuIndices : STA !DP_JSLTarget

    ; Set bank of action_submenu
    ; instead of the menu we're jumping to
    LDA.l #action_submenu>>16 : STA !DP_JSLTarget+2

    ; Set return address for indirect JSL
    PHK : PEA .end-1

    ; Pre-load address in A/Y and jump to routine
    LDA [!DP_MenuIndices] : TAY
    LDX #$0000
    JML [!DP_JSLTarget]

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
    LDA $004214 : STA !DP_Temp

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Tens digit
    LDA !DP_Temp : BEQ .blanktens
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
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !DP_ThirdDigit

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !DP_ThirdDigit : BEQ .blanktens
    STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA ; waste cycles
    LDA $004214 : STA !DP_Temp

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Hundreds digit
    LDA !DP_Temp : BEQ .blankhundreds : ASL : TAY
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
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !DP_SecondDigit

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+6,X

    LDA !DP_SecondDigit : BEQ .blanktens
    STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA ; waste cycles
    LDA $004214 : STA !DP_ThirdDigit

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !DP_ThirdDigit : BEQ .blankhundreds
    STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA
    LDA $004214 : STA !DP_Temp

    ; Hundreds digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Thousands digit
    LDA !DP_Temp : BEQ .blankthousands
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
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $F0F0 : PLB : PLB ; waste cycles + set data bank
    LDA $004214 : STA !DP_FirstDigit

    ; Ones digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+8,X

    LDA !DP_FirstDigit : BNE +
    BRL .blanktens
+   STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA ; waste cycles
    LDA $004214 : STA !DP_SecondDigit

    ; Tens digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+6,X

    LDA !DP_SecondDigit : BNE +
    BRL .blankhundreds
+   STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA ; waste cycles
    LDA $004214 : STA !DP_ThirdDigit

    ; Hundreds digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+4,X

    LDA !DP_ThirdDigit : BEQ .blankthousands
    STA $004204
    %a8()
    LDA #$0A : STA $004206 ; divide by 10
    %a16()
    PEA $0000 : PLA ; waste cycles
    LDA $004214 : STA !DP_Temp

    ; Thousands digit
    LDA $004216 : ASL : TAY
    LDA.w NumberGFXTable,Y : STA !ram_tilemap_buffer+2,X

    ; Ten thousands digit
    LDA !DP_Temp : BEQ .blanktenthousands
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
    ; store 16-bit dividend
    STA $4204

    %a8()
    ; divide by 100
    LDA #$64 : STA $4206

    %a16()
    PEA $0000 : PLA ; wait for math

    ; store result and use remainder as new dividend
    LDA $4214 : STA !DP_Temp
    LDA $4216 : STA $4204

    %a8()
    ; divide by 10
    LDA #$0A : STA $4206

    %a16()
    PEA $0000 : PLA ; wait for math

    ; store result and remainder, divide the rest
    LDA $4214 : STA !DP_SecondDigit ; tens
    LDA $4216 : STA !DP_ThirdDigit ; ones
    LDA !DP_Temp : STA $4204

    %a8()
    ; divide by 10
    LDA #$0A : STA $4206

    %a16()
    PEA $0000 : PLA ; wait for math

    ; store result and remainder
    LDA $4214 : STA !DP_Temp ; thousands
    LDA $4216 : STA !DP_FirstDigit ; hundreds

    RTS
}

cm_reverse_hex2dec:
{
; Reconstructs a 16bit decimal number from individual digit values
    LDA !DP_Temp
    %ai8()
    STA $211B : XBA : STA $211B ; Thousands
    LDY #$0A : STY $211C ; multiply by 10
    %a16()
    LDA $2134 : CLC : ADC !DP_FirstDigit ; add Hundreds
    %a8()
    STA $211B : XBA : STA $211B
    STY $211C ; multiply by 10
    %a16()
    LDA $2134 : CLC : ADC !DP_SecondDigit ; add Tens
    %a8()
    STA $211B : XBA : STA $211B 
    STY $211C ; multiply by 10
    %ai16()
    LDA $2134 : CLC : ADC !DP_ThirdDigit : STA !DP_DigitValue ; add Ones
    RTS
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
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'

HexGFXTable:
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'A', $2900|'B', $2900|'C', $2900|'D', $2900|'E', $2900|'F'

HexToNumberGFX1:
    dw $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0', $2900|'0'
    dw $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1', $2900|'1'
    dw $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2', $2900|'2'
    dw $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3', $2900|'3'
    dw $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4', $2900|'4'
    dw $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5', $2900|'5'

HexToNumberGFX2:
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'
    dw $2900|'0', $2900|'1', $2900|'2', $2900|'3', $2900|'4', $2900|'5', $2900|'6', $2900|'7', $2900|'8', $2900|'9'

ControllerInputTable:
;       Up     Down   Left   Right  L
    dw $0800, $0400, $0200, $0100, $0020
;       A      B      X      Y      R
    dw $0080, $8000, $0040, $4000, $0010

ControllerGFXTable:
;       Up     Down   Left   Right  L
    dw $2973, $2972, $2971, $2970, $297D
;       A      B      X      Y      R
    dw $297F, $2977, $297E, $2976, $297C

%endfree(F0)
