
; -------------
; Memory Editor
; -------------

print pc, " memory editor start"
MemoryEditorMenu:
    dw #memory_addr_bank
    dw #memory_addr_hi
    dw #memory_addr_lo
    dw #$FFFF
    dw #memory_size
    dw #$FFFF
    dw #memory_edit_hi
    dw #memory_edit_lo
    dw #memory_edit_write
    dw #$0000
    %cm_header("MEMORY EDITOR")
    %cm_footer("NEARBY MEMORY SHOWN HERE")

memory_addr_bank:
    %cm_numfield_hex("Address Bank Byte", !ram_mem_address_bank, 0, 255, 1, 8, #0)

memory_addr_hi:
    %cm_numfield_hex("Address High Byte", !ram_mem_address_hi, 0, 255, 1, 8, .routine)
  .routine
    %a8()
    XBA : LDA !ram_mem_address_lo
    STA !ram_mem_address
    RTL

memory_addr_lo:
    %cm_numfield_hex("Address Low Byte", !ram_mem_address_lo, 0, 255, 1, 8, .routine)
  .routine
    %a8()
    XBA : LDA !ram_mem_address_hi : XBA
    STA !ram_mem_address
    RTL

memory_size:
    dw !ACTION_CHOICE
    dl #!ram_mem_memory_size
    dw #$0000
    db !PALETTE_TEXT, "Size", #$FF
    db !PALETTE_SPECIAL, "     16-BIT", #$FF
    db !PALETTE_SPECIAL, "      8-BIT", #$FF
    db $FF

memory_edit_hi:
    %cm_numfield_hex("Edit High Byte", !ram_mem_editor_hi, 0, 255, 1, 8, #0)

memory_edit_lo:
    %cm_numfield_hex("Edit Low Byte", !ram_mem_editor_lo, 0, 255, 1, 8, #0)

memory_edit_write:
    %cm_jsl("Write to Address", .routine, #0)
  .routine
    %a8()
    LDA !ram_mem_address_lo : STA $40
    LDA !ram_mem_address_hi : STA $41
    LDA !ram_mem_address_bank : STA $42
    LDA !ram_mem_memory_size : BNE .eight_bit
    LDA !ram_mem_editor_hi : XBA : LDA !ram_mem_editor_lo
    %a16()
    STA [$40]
    RTL
  .eight_bit
    LDA !ram_mem_editor_hi : XBA : LDA !ram_mem_editor_lo
    STA [$40]
    RTL


cm_editor_menu_prep:
{
    LDA #$0001 : STA !ram_mem_editor_active

    ; split address hi and lo
    LDA !ram_mem_address
    %a8()
    STA !ram_mem_address_lo : XBA : STA !ram_mem_address_hi
    %a16()

    ; clear tilemap
    JSL cm_tilemap_bg

    RTL
}


cm_memory_editor:
; Draws the memory values identified by the last digit of the 24-bit address
{
    LDA !ram_mem_editor_active : BNE +
    RTL

    ; assemble address word
+   %a8()
    LDA !ram_mem_address_hi : XBA : LDA !ram_mem_address_lo
    %a16()
    STA !ram_mem_address

    ; draw the address bank
    LDA !ram_mem_address_bank : STA !ram_draw_value
    LDX #$044E : JSL cm_draw2_hex

    ; draw the address word
    %a16()
    LDA !ram_mem_address : STA !ram_draw_value
    LDX #$0452 : JSL cm_draw4_hex

    ; assemble indirect address
    LDA !ram_mem_address_bank : STA $42
    LDA !ram_mem_address : STA $40
    LDA [$40] : STA !ram_draw_value

    ; 16-bit or 8-bit
    LDA !ram_mem_memory_size : BNE .eight_bit

    ; draw the 16-bit hex value at address
    LDX #$042A : JSL cm_draw4_hex
    LDX #$0468 : JSL cm_draw5
    BRA .labels

  .eight_bit
    ; draw the 8-bit hex value at address
    %a8()
    LDX #$042A : JSL cm_draw2_hex
    LDX #$0468 : JSL cm_draw3

  .labels
    ; bunch of $ symbols
    LDA #$295F : STA !ram_tilemap_buffer+$172 ; $Bank
    LDA #$295F : STA !ram_tilemap_buffer+$1B2 ; $High
    LDA #$295F : STA !ram_tilemap_buffer+$1F2 ; $Low
    LDA #$295F : STA !ram_tilemap_buffer+$2F2 ; $High
    LDA #$295F : STA !ram_tilemap_buffer+$332 ; $Low
    LDA #$295F : STA !ram_tilemap_buffer+$428 ; $Value
    LDA #$295F : STA !ram_tilemap_buffer+$44C ; $Address

    ; labeling for newbies
    LDA #$2D77 : STA !ram_tilemap_buffer+$40E ; B
    LDA #$2D77 : STA !ram_tilemap_buffer+$410 ; B
    LDA #$2D47 : STA !ram_tilemap_buffer+$412 ; H
    LDA #$2D48 : STA !ram_tilemap_buffer+$414 ; I
    LDA #$2D7D : STA !ram_tilemap_buffer+$416 ; L
    LDA #$2D4E : STA !ram_tilemap_buffer+$418 ; O

    ; HEX and DEC labels
    LDA #$2D47 : STA !ram_tilemap_buffer+$420 ; H
    LDA #$2D44 : STA !ram_tilemap_buffer+$422 ; E
    LDA #$2D7E : STA !ram_tilemap_buffer+$424 ; X
    LDA #$2D43 : STA !ram_tilemap_buffer+$460 ; D
    LDA #$2D44 : STA !ram_tilemap_buffer+$462 ; E
    LDA #$2D42 : STA !ram_tilemap_buffer+$464 ; C

    ; setup to draw $10 bytes of nearby RAM
    LDX #$0508
    %a8()
    LDA #$00 : STA !ram_mem_line_position : STA !ram_mem_loop_counter
    LDA $40 : AND #$F0 : STA $40

  .drawLowerHalfNearby
    ; draw a byte
    LDA [$40] : STA !ram_draw_value
    JSL cm_draw2_hex
    INC $40

    ; inc tilemap position
    INX #6 : LDA !ram_mem_line_position : INC
    STA !ram_mem_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !ram_mem_line_position
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05BA : BPL .doneLowerHalf
    %a8()

    ; inc bytes drawn
+   LDA !ram_mem_loop_counter : INC : STA !ram_mem_loop_counter
    CMP #$10 : BNE .drawLowerHalfNearby
    %a16()

  .doneLowerHalf
    RTL

  .drawUpperHalf
    %a16()
    LDA !ram_mem_address_bank : STA $46
    LDA !ram_mem_address : STA $44
    LDA [$44] : STA !ram_draw_value
    LDX #$01E8 : JSL cm_draw4_hex

    LDX #$048A
    %a8()
    LDA #$00 : STA !ram_mem_line_position : STA !ram_mem_loop_counter
    LDA $44 : AND #$F0 : STA $44

  .drawUpperHalfNearby
    ; draw a byte
    LDA [$44] : STA !ram_draw_value
    JSL cm_draw2_hex
    INC $44

    ; inc tilemap position
    INX #6 : LDA !ram_mem_line_position : INC
    STA !ram_mem_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !ram_mem_line_position
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05BA : BPL .doneUpperHalf
    %a8()

    ; inc bytes drawn
+   LDA !ram_mem_loop_counter : INC : STA !ram_mem_loop_counter
    CMP #$10 : BNE .drawUpperHalfNearby
    %a16()

  .doneUpperHalf
    RTL
}

print pc, " memory editor end"
