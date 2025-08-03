
; -----------------------
; Customize Practice Menu
; -----------------------

CustomizeMenu:
    dw #custom_menubackground
    dw #$FFFF
    dw #custom_custompalettes_menu
    dw #$FFFF
    dw #custom_paletteprofile
    dw #custom_palette2custom
    dw #$0000
    %cm_header("CUSTOMIZE PRACTICE MENU")

custom_menubackground:
    %cm_toggle("Menu Background", !sram_menu_background, #$0001, #.routine)
  .routine
    LDA !sram_menu_background : BNE .background
    LDA #$0140 : STA !ram_cm_blank_tile
    RTL

  .background
    LDA #$2540 : STA !ram_cm_blank_tile
    RTL

custom_custompalettes_menu:
    %cm_submenu("Customize Menu Palette", #CustomPalettesMenu)

custom_paletteprofile:
    dw !ACTION_CHOICE
    dl #!sram_pal_profile
    dw .routine
    db !PALETTE_TEXT, "Menu Palette", #$FF
    db !PALETTE_SPECIAL, "     CUSTOM", #$FF ; CUSTOM should always be first
    db !PALETTE_SPECIAL, "        RED", #$FF
    db !PALETTE_SPECIAL, "      GREEN", #$FF
    db !PALETTE_SPECIAL, "      BROWN", #$FF
    db #$FF
  .routine
    JSL cm_copy_cgram
    JSL cm_transfer_menu_cgram
    RTL

custom_palette2custom:
    %cm_jsl("Copy Palette to Custom", .routine, #$0000)
  .routine
    JSL copy_menu_palette
    RTL

CustomPalettesMenu:
    dw #palettes_header_outline
    dw #palettes_header_fill
    dw #palettes_text_outline
    dw #palettes_text_fill
    dw #palettes_special_outline
    dw #palettes_special_fill
    dw #palettes_selected_outline
    dw #palettes_selected_fill
    dw #palettes_background
    dw #$FFFF
    dw #palettes_display_menu
    dw #$0000
    %cm_header("CUSTOMIZE MENU PALETTE")

palettes_header_outline:
    %palettemenu("Header Outline", PalettesMenu_HeaderOutline, !sram_pal_header_outline)

palettes_header_fill:
    %palettemenu("Header Fill", PalettesMenu_HeaderFill, !sram_pal_header_fill)

palettes_text_outline:
    %palettemenu("Text Outline", PalettesMenu_TextOutline, !sram_pal_text_outline)

palettes_text_fill:
    %palettemenu("Text Fill", PalettesMenu_TextFill, !sram_pal_text_fill)

palettes_special_outline:
    %palettemenu("Special Outline", PalettesMenu_Special_Outline, !sram_pal_special_outline)

palettes_special_fill:
    %palettemenu("Special Fill", PalettesMenu_Special_Fill, !sram_pal_special_fill)

palettes_selected_outline:
    %palettemenu("Selected Text Outline", PalettesMenu_SelectOutline, !sram_pal_selected_outline)

palettes_selected_fill:
    %palettemenu("Selected Text Fill", PalettesMenu_SelectFill, !sram_pal_selected_fill)

palettes_background:
    %palettemenu("Background", PalettesMenu_Background, !sram_pal_background)

palettes_hex_red:
    %cm_numfield_color("Hexadecimal Red", !ram_pal_red, #MixRGB_long)

palettes_hex_green:
    %cm_numfield_color("Hexadecimal Green", !ram_pal_green, #MixRGB_long)

palettes_hex_blue:
    %cm_numfield_color("Hexadecimal Blue", !ram_pal_blue, #MixRGB_long)

palettes_dec_red:
    %cm_numfield("Decimal Red", !ram_pal_red, 0, 31, 1, 2, #MixRGB_long)

palettes_dec_green:
    %cm_numfield("Decimal Green", !ram_pal_green, 0, 31, 1, 2, #MixRGB_long)

palettes_dec_blue:
    %cm_numfield("Decimal Blue", !ram_pal_blue, 0, 31, 1, 2, #MixRGB_long)

MixRGB_long:
{
    JSL MixRGB
    RTL
}

MixBGR:
{
    JSL cm_colors
    JSL MixRGB_long
    RTL
}


palettes_display_menu:
    %cm_submenu("Screenshot To Share Colors", #PalettesDisplayMenu)

PalettesDisplayMenu:
    dw #display_header_outline
    dw #display_header_fill
    dw #display_text_outline
    dw #display_text_fill
    dw #display_special_outline
    dw #display_special_fill
    dw #display_selected_outline
    dw #display_selected_fill
    dw #display_background
    dw #$0000
    %cm_header("SHARE YOUR COLORS")

display_header_outline:
    %cm_numfield_hex_word("Header Outline", !sram_pal_header_outline)

display_header_fill:
    %cm_numfield_hex_word("Header Fill", !sram_pal_header_fill)

display_text_outline:
    %cm_numfield_hex_word("Text Outline", !sram_pal_text_outline)

display_text_fill:
    %cm_numfield_hex_word("Text Fill", !sram_pal_text_fill)

display_special_outline:
    %cm_numfield_hex_word("Special Outline", !sram_pal_special_outline)

display_special_fill:
    %cm_numfield_hex_word("Special Fill", !sram_pal_special_fill)

display_selected_outline:
    %cm_numfield_hex_word("Selected Text Outline", !sram_pal_selected_outline)

display_selected_fill:
    %cm_numfield_hex_word("Selected Text Fill", !sram_pal_selected_fill)

display_background:
    %cm_numfield_hex_word("Background", !sram_pal_background)


; ---------
; Menu Code
; ---------

PrepMenuPalette:
{
    LDA !sram_pal_profile : BEQ .customPalette
    ASL : TAX

    PHB
    PHK : PLB
    LDA.l PaletteProfileTable,X : STA $38
    LDY #$0002 : LDA ($38),Y : STA !ram_pal_header_outline
    LDY #$0006 : LDA ($38),Y : STA !ram_pal_header_fill
    LDY #$000A : LDA ($38),Y : STA !ram_pal_text_outline
    LDY #$000E : LDA ($38),Y : STA !ram_pal_text_fill
    LDY #$0012 : LDA ($38),Y : STA !ram_pal_special_outline
    LDY #$0016 : LDA ($38),Y : STA !ram_pal_special_fill
    LDY #$001A : LDA ($38),Y : STA !ram_pal_selected_outline
    LDY #$001E : LDA ($38),Y : STA !ram_pal_selected_fill
    LDY #$0004 : LDA ($38),Y
    STA !ram_pal_background : STA !ram_cm_cgram+$0C
    STA !ram_cm_cgram+$14 : STA !ram_cm_cgram+$1C
    PLB
    RTL

  .customPalette
    LDA !sram_pal_header_outline : STA !ram_pal_header_outline
    LDA !sram_pal_header_fill : STA !ram_pal_header_fill
    LDA !sram_pal_text_outline : STA !ram_pal_text_outline
    LDA !sram_pal_text_fill : STA !ram_pal_text_fill
    LDA !sram_pal_special_outline : STA !ram_pal_special_outline
    LDA !sram_pal_special_fill : STA !ram_pal_special_fill
    LDA !sram_pal_selected_outline : STA !ram_pal_selected_outline
    LDA !sram_pal_selected_fill : STA !ram_pal_selected_fill
    LDA !sram_pal_background
    STA !ram_pal_background : STA !ram_cm_cgram+$0C
    STA !ram_cm_cgram+$14 : STA !ram_cm_cgram+$1C
    RTL
}

copy_menu_palette:
{
    PHB
    PHK : PLB
    LDA !sram_pal_profile : BNE +
    BRL .fail
+   ASL : TAX : LDA.l PaletteProfileTable,X : STA $3A

    ; copy table to SRAM
    LDY #$0002 : LDA ($3A),Y : STA !sram_pal_header_outline
    LDY #$0006 : LDA ($3A),Y : STA !sram_pal_header_fill
    LDY #$000A : LDA ($3A),Y : STA !sram_pal_text_outline
    LDY #$000E : LDA ($3A),Y : STA !sram_pal_text_fill
    LDY #$0012 : LDA ($3A),Y : STA !sram_pal_special_outline
    LDY #$0016 : LDA ($3A),Y : STA !sram_pal_special_fill
    LDY #$001A : LDA ($3A),Y : STA !sram_pal_selected_outline
    LDY #$001E : LDA ($3A),Y : STA !sram_pal_selected_fill
    LDY #$000C : LDA ($3A),Y : STA !sram_pal_background

    ; refresh current profile
    JSL refresh_custom_palettes
;    %sfxbubble()
    PLB
    RTL

  .fail
    ; no SFX yet, do nothing
;    %sfxdachora()
    PLB
    RTL
}

refresh_custom_palettes:
{
    PHP
    %ai16()
    LDA #$0000 : STA !sram_pal_profile
    JSL cm_copy_cgram
    JSL cm_transfer_menu_cgram
    PLP
    RTL
}

cm_copy_cgram:
{
    ; Custom or pre-made palette
    LDA !sram_pal_profile : BEQ .custom
    ASL : TAX
    LDA.l PaletteProfileTable,X : STA $38
    LDA.w #PaletteProfileTable>>16 : STA $3A

    LDX #$0000
-   LDA [$38] : STA !ram_cm_cgram,X
    INC $38 : INC $38
    INX #2 : CPX #$0020 : BMI -
    RTL

  .custom
    LDA !sram_pal_header_outline : STA !ram_pal_header_outline
    LDA !sram_pal_header_fill : STA !ram_pal_header_fill
    LDA !sram_pal_text_outline : STA !ram_pal_text_outline
    LDA !sram_pal_text_fill : STA !ram_pal_text_fill
    LDA !sram_pal_special_outline : STA !ram_pal_special_outline
    LDA !sram_pal_special_fill : STA !ram_pal_special_fill
    LDA !sram_pal_selected_outline : STA !ram_pal_selected_outline
    LDA !sram_pal_selected_fill : STA !ram_pal_selected_fill
    LDA !sram_pal_background
    STA !ram_pal_background : STA !ram_cm_cgram+$0C
    STA !ram_cm_cgram+$14 : STA !ram_cm_cgram+$1C

    JSL PrepMenuPalette
    RTL
}

PaletteProfileTable:
    dw #CustomPaletteProfile ; dummy
    dw #RedPaletteProfile
    dw #GreenPaletteProfile
    dw #BrownPaletteProfile

;         Header Back   Header        Text   Back   Text          SpecialBack   Special       Select Back   Select 
;         Outer  Ground Fill          Outer  Ground Fill          Outer  Ground Fill          Outer  Ground Fill   
CustomPaletteProfile:
dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000 ; delete later

RedPaletteProfile:
dw $0000, $001F, $0000, $4B5F, $0000, $365F, $0000, $0095, $0000, $00FF, $0000, $03FF, $0000, $577D, $0000, $001F

GreenPaletteProfile:
dw $0000, $1DE6, $0000, $03E0, $0000, $026A, $0000, $05E6, $0000, $01FA, $0000, $035F, $0000, $01A0, $0000, $03E0

BrownPaletteProfile:
dw $0000, $0132, $0000, $01FA, $0000, $0132, $0000, $0889, $0000, $01FA, $0000, $035F, $0000, $19B3, $0000, $2636


cm_colors:
{
    ; exit if not in color menu
    LDA !ram_cm_stack_index : DEC #2 : TAX
    LDA !ram_cm_menu_stack,X : CMP #CustomPalettesMenu : BNE .done
    LDA !ram_cm_cursor_stack,X : TAX ; index for color menu table
    CMP #$0012 : BPL .done ; exit if beyond table boundaries

    PHB : PHK : PLB
    JSR (ColorMenuTable,X) ; runs cm_setup_RGB for selected menu
    PLB

  .done
    RTL
}

cm_setup_RGB:
{
    ; Split 15-bit SNES "BGR" color value into individual 5-bit RGB values
    LDA [$38] : AND #$7C00 : XBA : LSR #2 : STA !ram_pal_blue
    LDA [$38] : AND #$03E0 : LSR #5 : STA !ram_pal_green
    LDA [$38] : AND #$001F : STA !ram_pal_red
    ; Split 16-bit value into two 16-bit values for the menu
    LDA [$38] : %a8() : STA !ram_pal_lo
    XBA : STA !ram_pal_hi
    %a16()
    RTL
}

MixRGB:
{
    ; figure out which menu element is being edited
    LDA !ram_cm_stack_index : DEC #2 : TAX
    LDA !ram_cm_cursor_stack,X : TAX
    LDA.l MenuPaletteTable,X : STA $38 ; store indirect address
    LDA.w #!SRAM_START>>16 : STA $3A ; store indirect bank

    ; mix RGB values
    LDA !ram_pal_blue : XBA : ASL #2 : STA $3C
    LDA !ram_pal_green : ASL #5 : ORA $3C : STA $3C
    LDA !ram_pal_red : ORA $3C
    STA [$38] ; store combined color value

    ; update split values as well
    %a8()
    STA !ram_pal_lo : XBA : STA !ram_pal_hi
    %a16()

    JSL refresh_custom_palettes
    RTL

MenuPaletteTable:
    dw !sram_pal_header_outline
    dw !sram_pal_header_fill
    dw !sram_pal_text_outline
    dw !sram_pal_text_fill
    dw !sram_pal_special_outline
    dw !sram_pal_special_fill
    dw !sram_pal_selected_outline
    dw !sram_pal_selected_fill
    dw !sram_pal_background
}

ColorMenuTable:
    dw ColorMenuTable_header_outline
    dw ColorMenuTable_header_fill
    dw ColorMenuTable_text_outline
    dw ColorMenuTable_text_fill
    dw ColorMenuTable_special_outline
    dw ColorMenuTable_special_fill
    dw ColorMenuTable_selected_outline
    dw ColorMenuTable_selected_fill
    dw ColorMenuTable_background

ColorMenuTable_header_outline:
    %setupRGB(!sram_pal_header_outline)

ColorMenuTable_header_fill:
    %setupRGB(!sram_pal_header_fill)

ColorMenuTable_text_outline:
    %setupRGB(!sram_pal_text_outline)

ColorMenuTable_text_fill:
    %setupRGB(!sram_pal_text_fill)

ColorMenuTable_special_outline:
    %setupRGB(!sram_pal_special_outline)

ColorMenuTable_special_fill:
    %setupRGB(!sram_pal_special_fill)

ColorMenuTable_selected_outline:
    %setupRGB(!sram_pal_selected_outline)

ColorMenuTable_selected_fill:
    %setupRGB(!sram_pal_selected_fill)

ColorMenuTable_background:
    %setupRGB(!sram_pal_background)
