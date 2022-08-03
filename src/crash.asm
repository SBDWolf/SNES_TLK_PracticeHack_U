
; -------------
; Crash Handler
; -------------

; This resource adds a crash handler to dump data to SRAM whenever
; one of the "crash vectors" is triggered
; While emulation mode vectors are reassigned, the crash hanlder is
; not setup to recognize it and will likely crash itself

; TLK probably had a break handler routine living in SRAM on dev carts


; Repoint emulation IRQ/BRK vector
org $00FFFE
    dw JML_BRKHandler

; Repoint jump to BRK handler
org $00A2E8
JML_BRKHandler:
    JML BRKHandler

; Repoint native COP vector
org $00FFE4
    dw JML_COPHandler

; Repoint emulation COP vector
org $00FFF4
    dw JML_COPHandler

; Setup jump to COP handler
org $00FFAC
JML_COPHandler:
    JML COPHandler


org $F40000
print pc, " crash handler bankF4 start"

; This routine (or a bridge to it) must live in bank $00
CrashHandler:
{
    PHP : PHB : PHD
    %ai16()

    ; store CPU registers
    STA !sram_crash_a
    TXA : STA !sram_crash_x
    TYA : STA !sram_crash_y
    PLA : STA !sram_crash_dp
    PLA : STA !sram_crash_dbp
    TSC : STA !sram_crash_sp
    LDX #$0000 : PHX : PLD                 ; clear X and reset DP
    PHX : PLB : PLB                        ; set DB to zero

    ; check condition of stack
    BMI .overflow
    CMP #$0300 : BPL .underflow

    ; store crash type, 0 = handler, 8000 = overflow, 4000 = underflow
    LDA #$0000 : STA !sram_crash_type      ; xxx0 = generic
    LDA !sram_crash_sp : INC : TAY
    BRA .loopStack

  .overflow
    LDA #$8000 : STA !sram_crash_type      ; 8xxx = stack overflow
    LDA #$01FF : TCS                       ; repair stack
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$0000                             ; dump $0000-$002F
    BRA .loopStack

  .underflow
    LDA #$4000 : STA !sram_crash_type      ; 4xxx = stack underflow
    LDA #$01FF : TCS                       ; repair stack
    LDA $001FFE : STA !sram_crash_temp     ; preserve stack bytes
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$02D0                             ; dump $02D0-$02FF

  .loopStack
    LDA $0000,Y : STA !sram_crash_stack,X
    INX #2 : CPX #$0030 : BEQ .saveStackSize
    BPL .maxStack ; max 30h bytes
    INY #2 : CPY #$0300 : BMI .loopStack
    BRA .stackSize

  .maxStack
    ; we only saved 30h bytes, so check for overflow
    LDA !sram_crash_type : BPL .countStackRemaining
    LDX #$FFFF : BRA .saveStackSize

  .countStackRemaining
    ; inc until we know the total number of bytes on the stack
    INY : INX : CPY #$0300 : BMI .maxStack

  .stackSize
    ; check if we copied an extra byte
    CPY #$0300 : BEQ .saveStackSize
    DEX ; don't count it
  .saveStackSize
    TXA : STA !sram_crash_stack_size

    ; restore last two stack bytes if underflow
    LDA !sram_crash_type : AND #$4000 : BEQ +
    LDA !sram_crash_temp : STA !sram_crash_stack+$2E

    ; launch CrashViewer to display dump
+   JML CrashViewer
}

BRKHandler:
{
    JML .setBank
  .setBank
    PHP : PHB : PHD
    %ai16()

    ; store CPU registers
    STA !sram_crash_a
    TXA : STA !sram_crash_x
    TYA : STA !sram_crash_y
    PLA : STA !sram_crash_dp
    PLA : STA !sram_crash_dbp
    TSC : STA !sram_crash_sp
    LDX #$0000 : PHX : PLD                 ; clear X and reset DP
    PHX : PLB : PLB                        ; set DB to zero

    ; check condition of stack
    BMI .overflow
    CMP #$0300 : BPL .underflow

    ; store crash type
    LDA #$0001 : STA !sram_crash_type      ; xxx1 = BRK
    LDA !sram_crash_sp : INC : TAY
    JMP CrashHandler_loopStack

  .overflow
    LDA #$8001 : STA !sram_crash_type      ; 8xxx = stack overflow
    LDA #$01FF : TCS                       ; repair stack
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$0000                             ; dump $0000-$002F
    JMP CrashHandler_loopStack

  .underflow
    LDA #$4001 : STA !sram_crash_type      ; 4xxx = stack underflow
    LDA #$01FF : TCS                       ; repair stack
    LDA $001FFE : STA !sram_crash_temp     ; preserve stack bytes
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$02FD                             ; dump $02FD-$02FF
    JMP CrashHandler_loopStack
}

COPHandler:
{
    JML .setBank
  .setBank
    PHP : PHB : PHD
    %ai16()

    ; store CPU registers
    STA !sram_crash_a
    TXA : STA !sram_crash_x
    TYA : STA !sram_crash_y
    PLA : STA !sram_crash_dp
    PLA : STA !sram_crash_dbp
    TSC : STA !sram_crash_sp
    LDX #$0000 : PHX : PLD                 ; clear X and reset DP
    PHX : PLB : PLB                        ; set DB to zero

    ; check condition of stack
    BMI .overflow
    CMP #$0300 : BPL .underflow

    ; store crash type
    LDA #$0002 : STA !sram_crash_type      ; xxx2 = COP
    LDA !sram_crash_sp : INC : TAY
    JMP CrashHandler_loopStack

  .overflow
    LDA #$8002 : STA !sram_crash_type      ; 8xxx = stack overflow
    LDA #$01FF : TCS                       ; repair stack (unused RAM @ $100-1FF)
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$0000                             ; dump $0000-$002F
    JMP CrashHandler_loopStack

  .underflow
    LDA #$4002 : STA !sram_crash_type      ; 4xxx = stack underflow
    LDA #$01FF : TCS                       ; repair stack
    LDA $001FFE : STA !sram_crash_temp     ; preserve stack bytes
    PHB : PHB : PLA : STA !sram_crash_dbp  ; salvage crash DB
    LDY #$02D0                             ; dump $02D0-$02FF
    JMP CrashHandler_loopStack
}

CrashViewer:
{
    ; setup to draw crashdump on layer 3
    %a8()
    LDA #$00 : PHA : PLB  ; Set DB for register access
    STZ $420C
    STZ $4357 : STZ $4359 ; clear HDMA settings
    LDA #$80 : STA $2100  ; Force blank on, zero brightness
    LDA #$A1 : STA $4200  ; NMI, V-blank IRQ, and auto-joypad read on
    LDA #$09 : STA $2105  ; BG3 priority on, BG Mode 1
    LDA #$77 : STA $210C  ; BG3 tileset address to $7000 ($F000 in VRAM)
    LDA #$7C : STA $2109  ; BG3 tilemap address, 32x32 size
    LDA #$04 : STA $212C  ; Enable BG3 on main screen
;    LDA #$04 : STA $212D  ; Enable BG3 on subscreen
;    LDA #$02 : STA $2130  ; Add subscreen to color math
;    LDA #$33 : STA $2131  ; Enable color math on backgrounds and OAM
    STZ $2111 : STZ $2111 ; Clear BG3 X scroll, write twice
    LDA #$1F : STA $2112  ; BG3 Y scroll low byte
    STZ $2112             ; BG3 Y scroll high byte
    LDA #$0F : STA $2100  ; Force blank off, max brightness

    %ai16()
    JSL crash_next_frame
    JSL crash_cgram_transfer
    JSL crash_tileset_transfer

    LDA #$0000 : STA !sram_crash_page : STA !sram_crash_palette : STA !sram_crash_cursor
    STA !sram_crash_input : STA !sram_crash_input_new : STA !sram_crash_input_prev
    LDA #$FF9E : STA !sram_crash_mem_viewer
    LDA #$007F : STA !sram_crash_mem_viewer_bank

    ; fall through to CrashLoop
}

CrashLoop:
{
    %ai16()
    ; Clear the screen
    LDA #$0D1F : LDX #$06FE
-   STA !crash_tilemap_buffer,X : DEX #2 : BPL -

    ; Determine which page to draw
    LDA !sram_crash_page : ASL : TAX
    JSR (CrashPageTable,X)

    ; Transfer to VRAM
    %ai16()
    JSL crash_next_frame
    JSL crash_read_inputs
    JSL crash_tilemap_transfer

    ; check for new inputs, copy to X
    LDA !sram_crash_input_new : TAX : BEQ CrashLoop

    ; check for soft reset shortcut (Select+Start+L+R)
    LDA !sram_crash_input : AND #$3030 : CMP #$3030 : BNE +
    AND !sram_crash_input_new : BEQ +
    JML $008000 ; Soft Reset

if !FEATURE_SAVESTATES
    ; check for load state shortcut
+   LDA !sram_crash_input : CMP !sram_ctrl_load_state : BNE +
    AND !sram_crash_input_new : BEQ +
    ; check if savestate exists
    LDA !SRAM_SAVED_STATE : CMP #$5AFE : BNE +
    ; prepare to jump to load_state
    %a8()
    LDA.b #ReadControllerInputs>>16 : PHA : PLB
    %a16()
    PEA.w ReadControllerInputs_crash_loadstate_return-1
    JML ControllerShortcuts_loadstate
endif

+   TXA : AND #$0010 : BNE .incPalette ; R
    TXA : AND #$0020 : BNE .decPalette ; L
    TXA : AND #$1080 : BNE .next       ; A or Start
    TXA : AND #$A000 : BNE .previous   ; B or Select
    JMP CrashLoop

  .previous
    LDA !sram_crash_page : BNE +
    LDA #$0003
+   DEC : STA !sram_crash_page
    JMP CrashLoop

  .next
    LDA !sram_crash_page : CMP #$0002 : BMI +
    LDA #$FFFF
+   INC : STA !sram_crash_page
    JMP CrashLoop

  .decPalette
    LDA !sram_crash_palette : BNE +
    LDA #$0008
+   DEC : STA !sram_crash_palette
    BRA .updateCGRAM

  .incPalette
    LDA !sram_crash_palette : CMP #$0007 : BMI +
    LDA #$FFFF
+   INC : STA !sram_crash_palette

  .updateCGRAM
    JSL crash_cgram_transfer
    JMP CrashLoop
}

CrashPageTable:
    dw CrashDump
    dw CrashMemViewer
    dw CrashInfo

CrashDump:
{
    %ai16()

    ; -- Draw header --
    LDA.l #CrashTextHeader : STA !sram_crash_text
    LDA.l #CrashTextHeader>>16 : STA !sram_crash_text_bank
    LDX #$0086 : JSR crash_draw_text

    ; -- Draw footer message --
    LDA.l #CrashTextFooter1 : STA !sram_crash_text
    LDA.l #CrashTextFooter1>>16 : STA !sram_crash_text_bank
    LDX #$0646 : JSR crash_draw_text

    LDA.l #CrashTextFooter2 : STA !sram_crash_text
    LDA.l #CrashTextFooter2>>16 : STA !sram_crash_text_bank
    LDX #$0686 : JSR crash_draw_text

    ; -- Draw register labels --
    LDA #$0D00 : STA !crash_tilemap_buffer+$108  ; A
    LDA #$0D17 : STA !crash_tilemap_buffer+$148  ; X
    LDA #$0D18 : STA !crash_tilemap_buffer+$188  ; Y
    LDA #$0D03 : STA !crash_tilemap_buffer+$118  ; D
                 STA !crash_tilemap_buffer+$158  ; D
    LDA #$0D0F : STA !crash_tilemap_buffer+$11A  ; P
                 STA !crash_tilemap_buffer+$12C  ; P
                 STA !crash_tilemap_buffer+$16A  ; P
    LDA #$0D01 : STA !crash_tilemap_buffer+$15A  ; B
    LDA #$0D12 : STA !crash_tilemap_buffer+$12A  ; S
                 STA !crash_tilemap_buffer+$16C  ; S

    ; -- Draw stack label --
    LDA.l #CrashTextStack1 : STA !sram_crash_text
    LDA.l #CrashTextStack1>>16 : STA !sram_crash_text_bank
    LDX #$020E : JSR crash_draw_text

    ; -- Draw stack text --
    LDA.l #CrashTextStack2 : STA !sram_crash_text
    LDA.l #CrashTextStack2>>16 : STA !sram_crash_text_bank
    LDX #$024C : JSR crash_draw_text

    ; -- Draw overflow/underflow warning text --
    LDA !sram_crash_type : AND #$C000 : BEQ .drawRegisters
    BMI .overflow

    LDA.l #CrashTextStack3 : STA !sram_crash_text
    LDA.l #CrashTextStack3>>16 : STA !sram_crash_text_bank
    LDX #$028E : JSR crash_draw_text
    BRA .drawRegisters

  .overflow
    LDA.l #CrashTextStack4 : STA !sram_crash_text
    LDA.l #CrashTextStack4>>16 : STA !sram_crash_text_bank
    LDX #$028E : JSR crash_draw_text

  .drawRegisters
    ; -- Draw register values --
    LDA !sram_crash_a : STA !sram_crash_draw_value
    LDX #$010C : JSR crash_draw4  ; A
    LDA !sram_crash_x : STA !sram_crash_draw_value
    LDX #$014C : JSR crash_draw4  ; X
    LDA !sram_crash_y : STA !sram_crash_draw_value
    LDX #$018C : JSR crash_draw4  ; Y

    ; Draw DP 
    LDA !sram_crash_dp : STA !sram_crash_draw_value
    LDX #$011E : JSR crash_draw4  ; DP

    ; DB/P is corrupt if over/underflow
    LDA !sram_crash_type : AND #$C000 : BNE .corruptP
    LDA !sram_crash_dbp : STA !sram_crash_draw_value
    LDX #$015E : JSR crash_draw2  ; DB
    LDA !sram_crash_draw_value : XBA : STA !sram_crash_draw_value
    LDX #$0170 : JSR crash_draw2  ; PS
    BRA +
  .corruptP
    LDA !sram_crash_dbp : STA !sram_crash_draw_value
    LDX #$015E : JSR crash_draw2  ; DB
    LDA #$0D8E  ; draw XX instead of PS
    STA !crash_tilemap_buffer+$170
    STA !crash_tilemap_buffer+$172

+   LDA !sram_crash_sp : STA !sram_crash_draw_value
    LDX #$0130 : JSR crash_draw4  ; SP

    ; -- Draw starting position of stack dump --
    LDA !sram_crash_type : AND #$C000 : BMI .overflowStart
    BNE .underflowStart
    LDA !sram_crash_draw_value : INC : STA !sram_crash_draw_value
    BRA .drawStartingPosition
  .overflowStart
    LDA #$0000 : STA !sram_crash_draw_value
    BRA .drawStartingPosition
  .underflowStart
    LDA #$1FD0 : STA !sram_crash_draw_value

  .drawStartingPosition
    LDX #$0268 : JSR crash_draw4

    ; -- Draw stack bytes written --
    LDA !sram_crash_stack_size : STA !sram_crash_draw_value
    BPL +
    LDA #$0030
+   STA !sram_crash_bytes_to_write
    LDX #$021E : JSR crash_draw4

    ; -- Detect and Draw COP/BRK --
    LDA !sram_crash_type : AND #$0003 : BEQ .drawStack_bridge
    LDA !sram_crash_type : AND #$C000 : BNE .corruptBRKCOP
    LDA $00 : PHA : LDA $02 : PHA

    %a8()
    LDA !sram_crash_stack : STA !sram_crash_draw_value
    LDX #$02E0 : JSR crash_draw2 ; P

    LDA !sram_crash_stack+$03 : STA !sram_crash_draw_value
    STA $02
    LDX #$02E8 : JSR crash_draw2 ; bank

    %a16()
    LDA !sram_crash_stack+$01 : DEC : STA $00
    DEC : STA !sram_crash_draw_value
    LDX #$02EC : JSR crash_draw4 ; addr

    LDA [$00] : STA !sram_crash_draw_value
    LDX #$02D8 : JSR crash_draw2 ; operand
    PLA : STA $02 : PLA : STA $00
    BRA .drawBRKCOPText

  .drawStack_bridge
    JMP .drawStack

  .corruptBRKCOP
    LDA #$0D8E  ; draw X's instead
    STA !crash_tilemap_buffer+$2D8
    STA !crash_tilemap_buffer+$2DA
    STA !crash_tilemap_buffer+$2E0
    STA !crash_tilemap_buffer+$2E2
    STA !crash_tilemap_buffer+$2E8
    STA !crash_tilemap_buffer+$2EA
    STA !crash_tilemap_buffer+$2EC
    STA !crash_tilemap_buffer+$2EE
    STA !crash_tilemap_buffer+$2F0
    STA !crash_tilemap_buffer+$2F2

  .drawBRKCOPText
    LDA !sram_crash_type : AND #$000F : CMP #$0002 : BEQ .COPcrash
    LDA #$0D01 : STA !crash_tilemap_buffer+$2CC ; B
    LDA #$0D11 : STA !crash_tilemap_buffer+$2CE ; R
    LDA #$0D0A : STA !crash_tilemap_buffer+$2D0 ; K
    LDA #$0D44 : STA !crash_tilemap_buffer+$2D4 ; #
    LDA #$0D4E : STA !crash_tilemap_buffer+$2D6 ; $
    STA !crash_tilemap_buffer+$2E6 ; $
    BRA .drawStack

  .COPcrash
    LDA #$0D02 : STA !crash_tilemap_buffer+$2CC ; C
    LDA #$0D7D : STA !crash_tilemap_buffer+$2CE ; O
    LDA #$0D0F : STA !crash_tilemap_buffer+$2D0 ; P
    LDA #$0D44 : STA !crash_tilemap_buffer+$2D4 ; #
    LDA #$0D4E : STA !crash_tilemap_buffer+$2D6 ; $
    STA !crash_tilemap_buffer+$2E6 ; $

  .drawStack
    ; -- Draw Stack Values --
    ; start by setting up tilemap position
    %ai16()
    LDX #$0348
    LDA #$0000 : STA !sram_crash_stack_line_position

    ; determine starting offset
    LDA !sram_crash_bytes_to_write
-   PHA : AND #$0007 : BEQ +
    TXA : CLC : ADC #$0006 : TAX
    LDA !sram_crash_stack_line_position : INC : STA !sram_crash_stack_line_position
    PLA : INC : BRA -

+   PLA : %a8()
    LDA #$00 : STA !sram_crash_loop_counter

  .drawStackLoop
    ; draw a byte
    PHX : %i8()
    LDA !sram_crash_loop_counter : TAX
    LDA !sram_crash_stack,X : STA !sram_crash_draw_value
    %i16() : PLX
    JSR crash_draw2

    ; inc tilemap position
    INX #6 : LDA !sram_crash_stack_line_position : INC
    STA !sram_crash_stack_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !sram_crash_stack_line_position
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05F4 : BPL .done
    %a8()

    ; inc bytes drawn
+   LDA !sram_crash_loop_counter : INC : STA !sram_crash_loop_counter
    CMP !sram_crash_bytes_to_write : BNE .drawStackLoop

  .done
    RTS
}

CrashMemViewer:
{
    ; -- Handle Dpad Inputs --
    %ai16()
    LDA !sram_crash_input_new : TAX : BNE .new_inputs
    LDA !sram_crash_input : BNE +
-   JMP .drawMemViewer

    ; check if any input held more than 24 frames
+   LDA !sram_crash_input_timer : CMP #$0018 : BMI -
    ; pass held input every other frame (slow down)
    AND #$0001 : BEQ -
    ; treat held (left/right) inputs as new
    LDA !sram_crash_input : AND #$0300 : TAX

  .new_inputs
    AND #$0800 : BNE .pressedUp
    TXA : AND #$0400 : BNE .pressedDown
    TXA : AND #$0200 : BNE .pressedLeft
    TXA : AND #$0100 : BNE .pressedRight
    JMP .drawMemViewer

  .pressedUp
    LDA !sram_crash_cursor : BNE +
    LDA #$0003
+   DEC : STA !sram_crash_cursor
    JMP .drawMemViewer

  .pressedDown
    LDA !sram_crash_cursor : CMP #$0002 : BMI +
    LDA #$FFFF
+   INC : STA !sram_crash_cursor
    JMP .drawMemViewer

  .decLowFast
    LDA !sram_crash_mem_viewer : DEC #4 : STA !sram_crash_mem_viewer
    JMP .drawMemViewer
  .pressedLeft
    LDA !sram_crash_cursor : BEQ .decBank
    DEC : BEQ .decHigh
    LDA !sram_crash_input : AND #$4040 : BNE .decLowFast
    LDA !sram_crash_mem_viewer : DEC : STA !sram_crash_mem_viewer
    JMP .drawMemViewer

  .incLowFast
    LDA !sram_crash_mem_viewer : INC #4 : STA !sram_crash_mem_viewer
    JMP .drawMemViewer
  .pressedRight
    LDA !sram_crash_cursor : BEQ .incBank
    DEC : BEQ .incHigh
    LDA !sram_crash_input : AND #$4040 : BNE .incLowFast
    LDA !sram_crash_mem_viewer : INC : STA !sram_crash_mem_viewer
    JMP .drawMemViewer

  .decBank
    LDA !sram_crash_input : AND #$4040 : BNE .decBankFast
    LDA !sram_crash_mem_viewer_bank : DEC : STA !sram_crash_mem_viewer_bank
    BRA .drawMemViewer
  .decBankFast
    LDA !sram_crash_mem_viewer_bank : DEC #4 : STA !sram_crash_mem_viewer_bank
    BRA .drawMemViewer

  .decHigh
    LDA !sram_crash_input : AND #$4040 : BNE .decHighFast
    LDA !sram_crash_mem_viewer : XBA : DEC : XBA : STA !sram_crash_mem_viewer
    BRA .drawMemViewer
  .decHighFast
    LDA !sram_crash_mem_viewer : XBA : DEC #4 : XBA : STA !sram_crash_mem_viewer
    BRA .drawMemViewer

  .incBank
    LDA !sram_crash_input : AND #$4040 : BNE .incBankFast
    LDA !sram_crash_mem_viewer_bank : INC : STA !sram_crash_mem_viewer_bank
    BRA .drawMemViewer
  .incBankFast
    LDA !sram_crash_mem_viewer_bank : INC #4 : STA !sram_crash_mem_viewer_bank
    BRA .drawMemViewer

  .incHigh
    LDA !sram_crash_input : AND #$4040 : BNE .incHighFast
    LDA !sram_crash_mem_viewer : XBA : INC : XBA : STA !sram_crash_mem_viewer
    BRA .drawMemViewer
  .incHighFast
    LDA !sram_crash_mem_viewer : XBA : INC #4 : XBA : STA !sram_crash_mem_viewer

    ; -- Draw Memory Viewer --
  .drawMemViewer
    %a16()
    ; draw cursor icons
    LDA !sram_crash_cursor : ASL : TAX
    LDA.l CursorPositions,X : TAX
    LDA #$0D80 : STA !crash_tilemap_buffer,X
    LDA #$0D81 : STA !crash_tilemap_buffer+$32,X

    ; draw header text
    LDA.l #CrashTextHeader2 : STA !sram_crash_text
    LDA.l #CrashTextHeader2>>16 : STA !sram_crash_text_bank
    LDX #$008C : JSR crash_draw_text

    ; draw footer text
    LDA.l #CrashTextFooter1 : STA !sram_crash_text
    LDA.l #CrashTextFooter1>>16 : STA !sram_crash_text_bank
    LDX #$0646 : JSR crash_draw_text

    LDA.l #CrashTextFooter2 : STA !sram_crash_text
    LDA.l #CrashTextFooter2>>16 : STA !sram_crash_text_bank
    LDX #$0686 : JSR crash_draw_text

    ; draw address text
    LDA.l #CrashTextMemAddress : STA !sram_crash_text
    LDA.l #CrashTextMemAddress>>16 : STA !sram_crash_text_bank
    LDX #$014E : JSR crash_draw_text

    ; draw value text
    LDA.l #CrashTextMemValue : STA !sram_crash_text
    LDA.l #CrashTextMemValue>>16 : STA !sram_crash_text_bank
    LDX #$01D2 : JSR crash_draw_text

    ; draw select bank
    LDA.l #CrashTextMemSelectBank : STA !sram_crash_text
    LDA.l #CrashTextMemSelectBank>>16 : STA !sram_crash_text_bank
    LDX #$0288 : JSR crash_draw_text

    ; draw select high
    LDA.l #CrashTextMemSelectHigh : STA !sram_crash_text
    LDA.l #CrashTextMemSelectHigh>>16 : STA !sram_crash_text_bank
    LDX #$0308 : JSR crash_draw_text

    ; draw select low
    LDA.l #CrashTextMemSelectLow : STA !sram_crash_text
    LDA.l #CrashTextMemSelectLow>>16 : STA !sram_crash_text_bank
    LDX #$0388 : JSR crash_draw_text

    ; draw the address
    %a8()
    LDA !sram_crash_mem_viewer_bank : STA !sram_crash_draw_value
    LDX #$0164 : JSR crash_draw2
    LDX #$02B4 : JSR crash_draw2
    %a16()
    LDA !sram_crash_mem_viewer : STA !sram_crash_draw_value
    LDX #$0168 : JSR crash_draw4
    %a8()
    LDX #$03B4 : JSR crash_draw2
    %a16()
    LDA !sram_crash_mem_viewer : XBA : STA !sram_crash_draw_value
    %a8()
    LDX #$0334 : JSR crash_draw2

    ; draw the current value and nearby bytes
    LDA !sram_crash_mem_viewer : BMI .drawUpperHalf
    %a16()
    LDA $00 : PHA : LDA $02 : PHA
    LDA !sram_crash_mem_viewer_bank : STA $02
    LDA !sram_crash_mem_viewer : STA $00
    LDA [$00] : STA !sram_crash_draw_value
    LDX #$01E8 : JSR crash_draw4

    LDX #$048A
    %a8()
    LDA #$00 : STA !sram_crash_stack_line_position : STA !sram_crash_loop_counter
    LDA $00 : AND #$F0 : STA $00

  .drawLowerHalfNearby
    ; draw a byte
    LDA [$00] : STA !sram_crash_draw_value
    JSR crash_draw2
    INC $00

    ; inc tilemap position
    INX #6 : LDA !sram_crash_stack_line_position : INC
    STA !sram_crash_stack_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !sram_crash_stack_line_position
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05BA : BPL .doneLowerHalf
    %a8()

    ; inc bytes drawn
+   LDA !sram_crash_loop_counter : INC : STA !sram_crash_loop_counter
    CMP #$10 : BNE .drawLowerHalfNearby
    %a16()

  .doneLowerHalf
    PLA : STA $02 : PLA : STA $00
    RTS

  .drawUpperHalf
    %a16()
    LDA $03 : PHA : LDA $06 : PHA
    LDA !sram_crash_mem_viewer_bank : STA $06
    LDA !sram_crash_mem_viewer : STA $03
    LDA [$03] : STA !sram_crash_draw_value
    LDX #$01E8 : JSR crash_draw4

    LDX #$048A
    %a8()
    LDA #$00 : STA !sram_crash_stack_line_position : STA !sram_crash_loop_counter
    LDA $03 : AND #$F0 : STA $03

  .drawUpperHalfNearby
    ; draw a byte
    LDA [$03] : STA !sram_crash_draw_value
    JSR crash_draw2
    INC $03

    ; inc tilemap position
    INX #6 : LDA !sram_crash_stack_line_position : INC
    STA !sram_crash_stack_line_position : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA !sram_crash_stack_line_position
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05BA : BPL .doneUpperHalf
    %a8()

    ; inc bytes drawn
+   LDA !sram_crash_loop_counter : INC : STA !sram_crash_loop_counter
    CMP #$10 : BNE .drawUpperHalfNearby
    %a16()

  .doneUpperHalf
    PLA : STA $06 : PLA : STA $03
    RTS

CursorPositions:
    dw $0286, $0306, $0386
}

CrashInfo:
{
    %ai16()

    ; draw header text
    LDA.l #CrashTextHeader3 : STA !sram_crash_text
    LDA.l #CrashTextHeader3>>16 : STA !sram_crash_text_bank
    LDX #$0086 : JSR crash_draw_text

    ; draw a bunch of text
    LDA.l #CrashTextInfo1 : STA !sram_crash_text
    LDA.l #CrashTextInfo1>>16 : STA !sram_crash_text_bank
    LDX #$0106 : JSR crash_draw_text

    LDA.l #CrashTextInfo2 : STA !sram_crash_text
    LDA.l #CrashTextInfo2>>16 : STA !sram_crash_text_bank
    LDX #$01C6 : JSR crash_draw_text

    LDA.l #CrashTextInfo3 : STA !sram_crash_text
    LDA.l #CrashTextInfo3>>16 : STA !sram_crash_text_bank
    LDX #$0206 : JSR crash_draw_text

    LDA.l #CrashTextInfo4 : STA !sram_crash_text
    LDA.l #CrashTextInfo4>>16 : STA !sram_crash_text_bank
    LDX #$0250 : JSR crash_draw_text

    LDA.l #CrashTextInfo5 : STA !sram_crash_text
    LDA.l #CrashTextInfo5>>16 : STA !sram_crash_text_bank
    LDX #$02C6 : JSR crash_draw_text

    LDA.l #CrashTextInfo6 : STA !sram_crash_text
    LDA.l #CrashTextInfo6>>16 : STA !sram_crash_text_bank
    LDX #$030A : JSR crash_draw_text

    LDA.l #CrashTextInfo7 : STA !sram_crash_text
    LDA.l #CrashTextInfo7>>16 : STA !sram_crash_text_bank
    LDX #$034E : JSR crash_draw_text

    LDA.l #CrashTextInfo8 : STA !sram_crash_text
    LDA.l #CrashTextInfo8>>16 : STA !sram_crash_text_bank
    LDX #$040A : JSR crash_draw_text

    LDA.l #CrashTextInfo9 : STA !sram_crash_text
    LDA.l #CrashTextInfo9>>16 : STA !sram_crash_text_bank
    LDX #$048E : JSR crash_draw_text

if !FEATURE_SAVESTATES
    LDA.l #CrashTextInfo10 : STA !sram_crash_text
    LDA.l #CrashTextInfo10>>16 : STA !sram_crash_text_bank
    LDX #$0546 : JSR crash_draw_text
endif

    LDA.l #CrashTextInfo11 : STA !sram_crash_text
    LDA.l #CrashTextInfo11>>16 : STA !sram_crash_text_bank
    LDX #$0588 : JSR crash_draw_text

    ; draw footer text
    LDA.l #CrashTextFooter1 : STA !sram_crash_text
    LDA.l #CrashTextFooter1>>16 : STA !sram_crash_text_bank
    LDX #$0646 : JSR crash_draw_text

    LDA.l #CrashTextFooter2 : STA !sram_crash_text
    LDA.l #CrashTextFooter2>>16 : STA !sram_crash_text_bank
    LDX #$0686 : JSR crash_draw_text

    RTS
}

crash_draw_text:
{
    ; X = pointer to tilemap area (STA !crash_tilemap_buffer,X)
    PHB : LDA #$0000 : PHA : PLB : PLB
    LDA $00 : PHA : LDA $02 : PHA
    LDA !sram_crash_text_bank : STA $02
    LDA !sram_crash_text : STA $00
    %a8()
    LDY #$0000

  .loop
    LDA [$00],Y : CMP #$FF : BEQ .end             ; terminator
    STA !crash_tilemap_buffer,X : INX             ; tile
    LDA #$0D : STA !crash_tilemap_buffer,X : INX  ; palette
    INY : BRA .loop

  .end
    %a16()
    PLA : STA $02 : PLA : STA $00
    PLB
    RTS
}

crash_draw4:
{
    PHP : %a16()
    PHB : PHK : PLB
    ; (X000)
    LDA !sram_crash_draw_value : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer,X
    ; (0X00)
    LDA !sram_crash_draw_value : AND #$0F00 : XBA : ASL : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer+2,X
    ; (00X0)
    LDA !sram_crash_draw_value : AND #$00F0 : LSR #3 : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer+4,X
    ; (000X)
    LDA !sram_crash_draw_value : AND #$000F : ASL : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer+6,X
    PLB : PLP
    RTS
}

crash_draw2:
{
    PHP : %a16()
    PHB : PHK : PLB
    ; (00X0)
    LDA !sram_crash_draw_value : AND #$00F0 : LSR #3 : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer,X
    ; (000X)
    LDA !sram_crash_draw_value : AND #$000F : ASL : TAY
    LDA.w CrashHexGFXTable,Y : STA !crash_tilemap_buffer+2,X
    PLB : PLP
    RTS
}

crash_cgram_transfer:
{
    PHP : %a16()

    LDA !sram_crash_palette : BEQ .white ; 0 index
    DEC : BEQ .grey      ; 1
    DEC : BEQ .green     ; 2
    DEC : BEQ .pink      ; 3
    DEC : BEQ .yellow    ; 4
    DEC : BEQ .blue      ; 5
    DEC : BEQ .red       ; 6
    DEC : BEQ .orange    ; 7

  .white
    LDA #$44E5 : STA !sram_crash_palette_12
    LDA #$7FFF : STA !sram_crash_palette_14
    BRA .transfer

  .grey
    LDA #$1CE7 : STA !sram_crash_palette_12
    LDA #$3DEF : STA !sram_crash_palette_14
    BRA .transfer

  .green
    LDA #$0000 : STA !sram_crash_palette_12
    LDA #$03E0 : STA !sram_crash_palette_14
    BRA .transfer

  .pink
    LDA #$0000 : STA !sram_crash_palette_12
    LDA #$5156 : STA !sram_crash_palette_14
    BRA .transfer

  .yellow
    LDA #$7C00 : STA !sram_crash_palette_12
    LDA #$03FF : STA !sram_crash_palette_14
    BRA .transfer

  .blue
    LDA #$7FFF : STA !sram_crash_palette_12
    LDA #$7A02 : STA !sram_crash_palette_14
    BRA .transfer

  .red
    LDA #$001F : STA !sram_crash_palette_12
    LDA #$7FE0 : STA !sram_crash_palette_14
    BRA .transfer

  .orange
    LDA #$7C60 : STA !sram_crash_palette_12
    LDA #$01FF : STA !sram_crash_palette_14

  .transfer
    %a8()
    LDA #$80 : STA $802100 ; enable forced blanking
    LDA #$0D : STA $002121 ; CGRAM addr to $01A/$0D
    LDA !sram_crash_palette_12 : STA $002122
    LDA !sram_crash_palette_12+1 : STA $002122
    LDA !sram_crash_palette_14 : STA $002122
    LDA !sram_crash_palette_14+1 : STA $002122
    LDA #$0F : STA $0F2100 ; disable forced blanking
    PLP
    RTL
}

crash_tileset_transfer:
{
    ; new
    %i8()
    LDX #$80 : STX $2100   ; enable forced blanking
    LDX #$80 : STX $2115   ; word-access, inc by 1
    LDA #$7800 : STA $2116 ; VRAM address ($F000 in VRAM)
    LDA #$1801 : STA $4300 ; low = word, normal increment (DMA MODE), high = destination (VRAM write register)
    LDA #CrashGFXTileset : STA $4302 ; source address
    LDX #CrashGFXTileset>>16 : STX $4304 ; source bank
    LDA #$0900 : STA $4305 ; size
    LDX #$01 : STX $420B   ; begin transfer, channel 0
    LDX #$0F : STX $2100   ; disable forced blanking
    %ai16()
    RTL
}

crash_tilemap_transfer:
{
    %a16()
    PHB : LDA #$0000 : PHA : PLB : PLB
    LDA #$7C80 : STA $2116 ; VRAM address ($F900 in VRAM)
    LDA #$1801 : STA $4350 ; low = word, normal increment (DMA MODE), high = destination (VRAM write register)
    LDA #!crash_tilemap_buffer : STA $4352 ; source address
    LDA.w #!crash_tilemap_buffer>>16 : STA $4354 ; source bank
    LDA #$0700 : STA $4355 ; size
    %a8()
    LDA #$80 : STA $2115 ; word-access, inc by 1
    LDA #$20 : STA $420B ; initiate DMA on channel 2
    %a16()
    PLB
    RTL
}

crash_next_frame:
{
    PHP : %a8()
    LDA !LK_NMI_Counter
-   CMP !LK_NMI_Counter : BEQ -
    PLP
    RTL
}

crash_read_inputs:
{
    PHP : %a8()
-   LDA $4212 : AND #$01 : BNE -

    %a16()
    LDA $4218 : STA !sram_crash_input
    EOR !sram_crash_input_prev : AND !sram_crash_input : STA !sram_crash_input_new

    LDA !sram_crash_input : BEQ .no_input
    CMP !sram_crash_input_prev : BNE .new_input

    ; inc timer while input held
    LDA !sram_crash_input_timer : INC : STA !sram_crash_input_timer : BPL .done
    LDA #$0018 : STA !sram_crash_input_timer ; wrap at 8000h
    BRA .done

  .no_input
    ; clear timer
    STA !sram_crash_input_timer
    BRA .done

  .new_input
    ; reset timer
    LDA #$0001 : STA !sram_crash_input_timer

  .done
    LDA !sram_crash_input : STA !sram_crash_input_prev
    PLP
    RTL
}


; ------------
; Text Strings
; ------------

CrashTextHeader:
    table ../resources/header.tbl
    db "LK SHOT ITSELF IN THE FOOT", #$FF
    table ../resources/normal.tbl

CrashTextFooter1:
; Navigate pages with A or B
    db "Navigate pages with ", #$8F, " or ", #$87, #$FF

CrashTextFooter2:
; Cycle palettes with L or R
    db "Cycle palettes with ", #$8D, " or ", #$8C, #$FF

CrashTextStack1:
    db "STACK:       Bytes", #$FF

CrashTextStack2:
    db "(starting at $    )", #$FF

CrashTextStack3:
    db "Stack UNDERFLOW!!", #$FF

CrashTextStack4:
    db "Stack OVERFLOW!!!", #$FF

CrashTextHeader2:
    table ../resources/header.tbl
    db "CRASH MEMORY VIEWER", #$FF
    table ../resources/normal.tbl

CrashTextMemAddress:
    db "ADDRESS:  $", #$FF

CrashTextMemValue:
    db "VALUE:    $", #$FF

CrashTextMemSelectBank:
    db "Select Address Bank  $", #$FF

CrashTextMemSelectHigh:
    db "Select Address High  $", #$FF

CrashTextMemSelectLow:
    db "Select Address Low   $", #$FF

CrashTextHeader3:
    table ../resources/header.tbl
    db "BUT WHAT DOES IT ALL MEAN?", #$FF
    table ../resources/normal.tbl

CrashTextInfo1:
    db "The Lion King has crashed!", #$FF

CrashTextInfo2:
    db "You can report this crash", #$FF

CrashTextInfo3:
    db "on GitHub, or in Discord's", #$FF

CrashTextInfo4:
    db "#general channel.", #$FF

CrashTextInfo5:
    db "Take a screenshot of the", #$FF

CrashTextInfo6:
    db "first page to help us", #$FF

CrashTextInfo7:
    db "diagnose the issue.", #$FF

CrashTextInfo8:
    db "LKpractice.spazer.link", #$FF

CrashTextInfo9:
    db "discord.gg/q8V7X45", #$FF

CrashTextInfo10:
    db "FXPAK users can load state", #$FF

CrashTextInfo11:
; Press LRSlSt to soft reset
    db "Press ", #$8D, #$8C, #$85, #$84, " to soft reset", #$FF

CrashHexGFXTable:
    dw $0D70, $0D71, $0D72, $0D73, $0D74, $0D75, $0D76, $0D77, $0D78, $0D79, $0D50, $0D51, $0D52, $0D53, $0D54, $0D55

; $900 bytes of font graphics
CrashGFXTileset:
incbin ../resources/CrashGFX.bin

print pc, " crash handler bankF4 end"
