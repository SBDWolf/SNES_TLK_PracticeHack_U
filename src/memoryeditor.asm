
; -------------
; Memory Editor
; -------------

MemoryEditorMenu:
    dw #memory_addr_bank
    dw #memory_addr
    dw #$FFFF
    dw #memory_size
    dw #$FFFF
    dw #memory_edit
    dw #memory_edit_write
    dw #$0000
    %cm_header("MEMORY EDITOR")
    %cm_footer("NEARBY MEMORY SHOWN HERE")

memory_addr_bank:
    %cm_numfield_hex("Address Bank Byte", !ram_mem_address_bank, 0, 255, 1, 8, #0)

memory_addr:
    %cm_numfield_hex_word("Address", !ram_mem_address, #$FFFF, #0)

memory_size:
    dw !ACTION_CHOICE
    dl #!ram_mem_memory_size
    dw #$0000
    db !PALETTE_TEXT, "Size", #$FF
    db !PALETTE_SPECIAL, "     16-BIT", #$FF
    db !PALETTE_SPECIAL, "      8-BIT", #$FF
    db $FF

memory_edit:
    %cm_numfield_hex_word("Value to Write", !ram_mem_editor, #$FFFF, #0)

memory_edit_write:
    %cm_jsl("Write to Address", .routine, #0)
  .routine
    ; setup indirect addressing
    LDA !ram_mem_address : STA !DP_Address
    LDA !ram_mem_address_bank : STA !DP_Address+2
    ; determine size
    LDA !ram_mem_memory_size : BEQ .sixteen
    %a8()
  .sixteen
    LDA !ram_mem_editor : STA [!DP_Address]
    RTL


cm_editor_menu_prep:
{
    LDA #$0001 : STA !ram_mem_editor_active
    JML cm_tilemap_bg
}


cm_memory_editor:
; Draws the memory values identified by the last digit of the 24-bit address
{
    LDA !ram_mem_editor_active : BNE +
    RTL

    ; draw the address bank
+   LDA !ram_mem_address_bank : STA !ram_draw_value
    LDX #$044E : JSL cm_draw2_hex

    ; draw the address word
    %a16()
    LDA !ram_mem_address : STA !ram_draw_value
    LDX #$0452 : JSL cm_draw4_hex

    ; assemble indirect address
    LDA !ram_mem_address_bank : STA !DP_Address+2
    LDA !ram_mem_address : STA !DP_Address
    LDA [!DP_Address] : STA !ram_draw_value

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
    LDA.w !PALETTE_SPECIAL<<8|'$'
    STA !ram_tilemap_buffer+$172 ; Bank
    STA !ram_tilemap_buffer+$1AE ; Address
    STA !ram_tilemap_buffer+$2AE ; Edit
    STA !ram_tilemap_buffer+$428 ; Value
    STA !ram_tilemap_buffer+$44C ; Address

    ; draw ADDRESS
    LDA.w !PALETTE_SELECTED<<8|'A' : STA !ram_tilemap_buffer+$40C
    LDA.w !PALETTE_SELECTED<<8|'D' : STA !ram_tilemap_buffer+$40E : STA !ram_tilemap_buffer+$410
    LDA.w !PALETTE_SELECTED<<8|'R' : STA !ram_tilemap_buffer+$412
    LDA.w !PALETTE_SELECTED<<8|'E' : STA !ram_tilemap_buffer+$414
    LDA.w !PALETTE_SELECTED<<8|'S' : STA !ram_tilemap_buffer+$416 : STA !ram_tilemap_buffer+$418

    ; HEX and DEC labels
    LDA.w !PALETTE_SELECTED<<8|'H' : STA !ram_tilemap_buffer+$420
    LDA.w !PALETTE_SELECTED<<8|'E' : STA !ram_tilemap_buffer+$422 : STA !ram_tilemap_buffer+$462
    LDA.w !PALETTE_SELECTED<<8|'X' : STA !ram_tilemap_buffer+$424
    LDA.w !PALETTE_SELECTED<<8|'D' : STA !ram_tilemap_buffer+$460
    LDA.w !PALETTE_SELECTED<<8|'C' : STA !ram_tilemap_buffer+$464

    ; setup to draw $10 bytes of nearby RAM
    LDX #$0508
    %a8()
    LDA #$00 : STA !ram_mem_line_position : STA !ram_mem_loop_counter
    LDA !DP_Address : AND #$F0 : STA !DP_Address

  .drawLowerHalfNearby
    ; draw a byte
    LDA [!DP_Address] : STA !ram_draw_value
    JSL cm_draw2_hex
    INC !DP_Address

    ; inc tilemap position
    INX #6
    LDA !ram_mem_line_position : INC
    STA !ram_mem_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !ram_mem_line_position
    %a16()
    ; skip a row and wrap to the beginning
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
    LDA !ram_mem_address_bank : STA !DP_Address+2
    LDA !ram_mem_address : STA !DP_Address
    LDA [!DP_Address] : STA !ram_draw_value
    LDX #$01E8 : JSL cm_draw4_hex

    LDX #$048A
    %a8()
    LDA #$00 : STA !ram_mem_line_position : STA !ram_mem_loop_counter
    LDA !DP_Address : AND #$F0 : STA !DP_Address

  .drawUpperHalfNearby
    ; draw a byte
    LDA [!DP_Address] : STA !ram_draw_value
    JSL cm_draw2_hex
    INC !DP_Address

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
