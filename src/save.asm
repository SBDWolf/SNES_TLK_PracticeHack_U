; SD2SNES Savestate code
; by acmlm, total, Myria
; adapted for Lion King by InsaneFirebat


; Savestate code variables
!SS_BANK = $F3F3
!SRAM_DMA_BANK = $296000
!SRAM_SAVED_SP = $266000
!SRAM_SAVED_AUDIO_11 = $266002
!SRAM_SAVED_AUDIO_21 = $266004
!SRAM_SAVED_AUDIO_6F = $266006
!SRAM_SAVED_AUDIO_C5 = $266008
!SRAM_SAVED_AUDIO_A68C = $26600A
!SRAM_SAVED_AUDIO_A68E = $26600C
!SRAM_SAVED_AUDIO_A690 = $26600E
!SRAM_SAVED_LEVEL = $266010
!SRAM_SAVED_RNG = $266080 ; 0x3
!SRAM_SAVED_STATE = $2660FE
!SRAM_SAVED_STACK = $266100

; APU RAM to investigate:
; 1F11
; 1F6F
; 1FC5
; A68C and surrounding?
; 

org $F30000
print pc, " save.asm start"
; These can be modified to do game-specific things before and after saving and loading
; Both A and X/Y are 16-bit here

; Lion King specific features to restore the correct music when loading a state below

pre_load_state:
{
    ; audio variables
    %a8()
    LDA $1F11 : STA !SRAM_SAVED_AUDIO_11
    LDA $1F6F : STA !SRAM_SAVED_AUDIO_6F
    LDA $1FC5 : STA !SRAM_SAVED_AUDIO_C5

    %ai16()
    LDA $1F21 : STA !SRAM_SAVED_AUDIO_21
    LDA $7EA68C : STA !SRAM_SAVED_AUDIO_A68C
    LDA $7EA68E : STA !SRAM_SAVED_AUDIO_A68E
    LDA $7EA690 : STA !SRAM_SAVED_AUDIO_A690

    LDA !LK_Current_Level : STA !SRAM_SAVED_LEVEL

    ; RNG features
    LDA !sram_savestate_rng : BEQ .done ; return if off
    CMP #$0001 : BEQ .preserve
    JSL !Cycle_RNG
    RTS

  .preserve
    LDA !LK_RNG_Seed+1 : STA !SRAM_SAVED_RNG+1
    LDA !LK_RNG_Seed : STA !SRAM_SAVED_RNG

  .done
    RTS
}

post_load_state:
{
    ; audio variables
    LDA !SRAM_SAVED_AUDIO_21 : STA $1F21
    LDA !SRAM_SAVED_AUDIO_A68C : STA $7EA68C
    LDA !SRAM_SAVED_AUDIO_A68E : STA $7EA68E
    LDA !SRAM_SAVED_AUDIO_A690 : STA $7EA690
    %a8()
    LDA !SRAM_SAVED_AUDIO_11 : STA $1F11
    LDA !SRAM_SAVED_AUDIO_6F : STA $1F6F
    LDA !SRAM_SAVED_AUDIO_C5 : STA $1FC5

    LDA !LK_Current_Level : CMP !SRAM_SAVED_LEVEL : BEQ .registers
    ; load music and repeat loadstate if level changed
    %a16()
    JSL Play_Level_Music
    LDA #$FFFF : STA !ram_loadstate_repeat ; jankness
    RTS

  .registers
    ; OBJ/BG1/BG2 enabled
    ; we're just guessing here but seems consistent so far
    ; title menu could use work here, it uses BG3
    LDA #$13 : STA $212C

  .setRNG
    %ai16()
    ; which RNG values to use?
    LDA !sram_savestate_rng : BEQ .done
    CMP #$0001 : BEQ .preserve
    JSL !Cycle_RNG
    RTS

  .preserve
    LDA !SRAM_SAVED_RNG+1 : STA !LK_RNG_Seed+1
    LDA !SRAM_SAVED_RNG : STA !LK_RNG_Seed

  .done
    RTS
}


; These restored registers are game-specific and needs to be updated for different games
register_restore_return:
{
    %ai16()
    LDA !ram_loadstate_repeat : BEQ .restore
    ; WARNING: Jank stuff ahead
    ; Repeat loadstate if we changed the music
    ; This corrects some corruption caused by loading music
    LDA #$0000 : STA !ram_loadstate_repeat
    JML load_state

  .restore
    JSL Reset_PPU_Registers
    %a8()
    LDA !LK_4200_NMIEnable : STA $4200
    LDA !LK_2100_Brightness : STA $2100
    RTL
}

save_state:
{
    PEA $0000 : PLB : PLB

    ; Store DMA registers to SRAM
    %a8()
    LDY #$0000 : TYX
    LDA #$80 : STA $802100 ; force blanking

  .save_dma_regs
    LDA $4300,X : STA !SRAM_DMA_BANK,X
    INX
    INY : CPY #$000B : BNE .save_dma_regs
    CPX #$007B : BEQ .save_dma_regs_done
    INX #5 : LDY #$0000
    BRA .save_dma_regs

  .save_dma_regs_done
    %ai16()
    LDA $00 : STA !SRAM_SAVED_STACK
    LDA $02 : STA !SRAM_SAVED_STACK+2
    LDX #save_write_table
    JMP run_vm

save_write_table:
    ; Turn PPU off
    dw $1000|$2100, $80
    dw $1000|$4200, $00
    ; Single address, B bus -> A bus.  B address = reflector to WRAM ($2180).
    dw $0000|$4350, $8080  ; direction = B->A, byte reg, B addr = $2180
    ; WRAM 7E0000-7E1FFF to SRAM 206000-207FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0020  ; A addr = $20xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7E2000-7E3FFF to SRAM 216000-217FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0021  ; A addr = $21xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $2000  ; WRAM addr = $xx2000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7E4000-7E5FFF to SRAM 226000-227FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0022  ; A addr = $22xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $4000  ; WRAM addr = $xx4000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7E6000-7E7FFF to SRAM 236000-237FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0023  ; A addr = $23xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $6000  ; WRAM addr = $xx6000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7E8000-7E9FFF to SRAM 246000-247FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0024  ; A addr = $24xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7EA000-7EBFFF to SRAM 256000-257FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0025  ; A addr = $25xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $A000  ; WRAM addr = $xxA000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7EC000-7EDFFF to SRAM 266000-267FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0026  ; A addr = $26xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $C000  ; WRAM addr = $xxC000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7EE000-7EFFFF to SRAM 276000-277FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0027  ; A addr = $27xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $E000  ; WRAM addr = $xxE000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7F0000-7F1FFF to SRAM 286000-287FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0028  ; A addr = $28xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7F2000-7F3FFF to SRAM 296000-297FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0029  ; A addr = $29xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $2000  ; WRAM addr = $xx2000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7F4000-7F5FFF to SRAM 2A6000-2A7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002A  ; A addr = $2Axxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $4000  ; WRAM addr = $xx4000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7F6000-7F7FFF to SRAM 2B6000-2B7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002B  ; A addr = $2Bxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $6000  ; WRAM addr = $xx6000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7F8000-7F9FFF to SRAM 2C6000-2C7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002C  ; A addr = $2Cxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7FA000-7FBFFF to SRAM 2D6000-2D7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002D  ; A addr = $2Dxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $A000  ; WRAM addr = $xxA000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7FC000-7FDFFF to SRAM 2E6000-2E7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002E  ; A addr = $2Exxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $C000  ; WRAM addr = $xxC000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; WRAM 7FE000-7FFFFF to SRAM 2F6000-2F7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002F  ; A addr = $2Fxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $E000  ; WRAM addr = $xxE000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5

    ; Address pair, B bus -> A bus.  B address = VRAM read ($2139).
    dw $0000|$4350, $3981  ; direction = B->A, word reg, B addr = $2139
    dw $1000|$2115, $0000  ; VRAM address increment mode.
    ; VRAM 0000-0FFF to SRAM 376000-377FFF
    dw $0000|$2116, $0001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0037  ; A addr = $37xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 1000-1FFF to SRAM 386000-387FFF
    dw $0000|$2116, $1001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0038  ; A addr = $38xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 2000-2FFF to SRAM 396000-397FFF
    dw $0000|$2116, $2001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0039  ; A addr = $39xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 3000-3FFF to SRAM 3A6000-3A7FFF
    dw $0000|$2116, $3001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003A  ; A addr = $3Axxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 4000-4FFF to SRAM 3B6000-3B7FFF
    dw $0000|$2116, $4001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003B  ; A addr = $3Bxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 5000-5FFF to SRAM 3C6000-3C7FFF
    dw $0000|$2116, $5001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003C  ; A addr = $3Cxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 6000-6FFF to SRAM 3D6000-3D7FFF
    dw $0000|$2116, $6001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003D  ; A addr = $3Dxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; VRAM 7000-7FFF to SRAM 3E6000-3E7FFF
    dw $0000|$2116, $7001  ; VRAM address >> 1.
    dw $9000|$2139, $0000  ; VRAM dummy read.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003E  ; A addr = $3Exxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($0000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; Copy CGRAM 000-1FF to SRAM 3F6000-3F61FF
    dw $1000|$2121, $00    ; CGRAM address
    dw $0000|$4350, $3B80  ; direction = B->A, byte reg, B addr = $213B
    dw $0000|$4352, $6000  ; A addr = $xx2000
    dw $0000|$4354, $003F  ; A addr = $3Fxxxx, size = $xx00
    dw $0000|$4356, $0002  ; size = $02xx ($0200), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; Done
    dw $0000, .save_return

  .save_return:
    PEA $8080 : PLB : PLB

    %ai16()
    LDA !SRAM_SAVED_STACK : STA $00
    LDA !SRAM_SAVED_STACK+2 : STA $02
    TSC : STA !SRAM_SAVED_SP
;    LDA !LK_Last_APU_Command : STA !SRAM_SAVED_LAST_APU
    LDA #$5AFE : STA !SRAM_SAVED_STATE
    JMP register_restore_return
}

load_state:
{
    LDA !SRAM_SAVED_STATE : CMP #$5AFE : BEQ +
;    %sfxfail()
    RTL

+   JSR pre_load_state
    PEA $8080 : PLB : PLB
    LDA $00 : STA !SRAM_SAVED_STACK
    LDA $02 : STA !SRAM_SAVED_STACK+2

    %a8()
    LDA #$80 : STA $802100 ; force blanking
    LDX #load_write_table
    JMP run_vm

load_write_table:
    ; Disable HDMA
    dw $1000|$420C, $00
    ; Turn PPU off
    dw $1000|$2100, $80
    dw $1000|$4200, $00
    ; Single address, A bus -> B bus.  B address = reflector to WRAM ($2180).
    dw $0000|$4350, $8000  ; direction = A->B, B addr = $2180
    ; SRAM 206000-207FFF to WRAM 7E0000-7E1FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0020  ; A addr = $20xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 216000-217FFF to WRAM 7E2000-7E3FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0021  ; A addr = $21xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $2000  ; WRAM addr = $xx2000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 226000-227FFF to WRAM 7E4000-7E5FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0022  ; A addr = $22xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $4000  ; WRAM addr = $xx4000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 236000-237FFF to WRAM 7E6000-7E7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0023  ; A addr = $23xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $6000  ; WRAM addr = $xx6000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 246000-247FFF to WRAM 7E8000-7E9FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0024  ; A addr = $24xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 256000-257FFF to WRAM 7EA000-7EBFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0025  ; A addr = $25xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $A000  ; WRAM addr = $xxA000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 266000-267FFF to WRAM 7EC000-7EDFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0026  ; A addr = $26xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $C000  ; WRAM addr = $xxC000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 276000-277FFF to WRAM 7EE000-7EFFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0027  ; A addr = $27xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $E000  ; WRAM addr = $xxE000
    dw $1000|$2183, $00    ; WRAM addr = $7Exxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 286000-287FFF to WRAM 7F0000-7F1FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0028  ; A addr = $28xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $0000  ; WRAM addr = $xx0000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 296000-297FFF to WRAM 7F2000-7F3FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0029  ; A addr = $29xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $2000  ; WRAM addr = $xx2000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2A6000-2A7FFF to WRAM 7F4000-7F5FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002A  ; A addr = $2Axxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $4000  ; WRAM addr = $xx4000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2B6000-2B7FFF to WRAM 7F6000-7F7FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002B  ; A addr = $2Bxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $6000  ; WRAM addr = $xx6000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2C6000-2C7FFF to WRAM 7F8000-7F9FFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002C  ; A addr = $2Cxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $8000  ; WRAM addr = $xx8000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2D6000-2D7FFF to WRAM 7FA000-7FBFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002D  ; A addr = $2Dxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $A000  ; WRAM addr = $xxA000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2E6000-2E7FFF to WRAM 7FC000-7FDFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002E  ; A addr = $2Exxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $C000  ; WRAM addr = $xxC000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 2F6000-2F7FFF to WRAM 7FE000-7FFFFF
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $002F  ; A addr = $2Fxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $0000|$2181, $E000  ; WRAM addr = $xxE000
    dw $1000|$2183, $01    ; WRAM addr = $7Fxxxx  (bank is relative to $7E)
    dw $1000|$420B, $20    ; Trigger DMA on channel 5

    ; Address pair, A bus -> B bus.  B address = VRAM write ($2118).
    dw $0000|$4350, $1801  ; direction = A->B, B addr = $2118
    dw $1000|$2115, $0000  ; VRAM address increment mode.
    ; SRAM 376000-377FFF to VRAM 0000-0FFF
    dw $0000|$2116, $0000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0037  ; A addr = $37xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 386000-387FFF to VRAM 1000-1FFF
    dw $0000|$2116, $1000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0038  ; A addr = $38xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 396000-397FFF to VRAM 2000-2FFF
    dw $0000|$2116, $2000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $0039  ; A addr = $39xxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3A6000-3A7FFF to VRAM 3000-3FFF
    dw $0000|$2116, $3000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003A  ; A addr = $3Axxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3B6000-3B7FFF to VRAM 4000-4FFF
    dw $0000|$2116, $4000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003B  ; A addr = $3Bxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3C6000-3C7FFF to VRAM 5000-5FFF
    dw $0000|$2116, $5000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003C  ; A addr = $3Cxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3D6000-3D7FFF to VRAM 6000-6FFF
    dw $0000|$2116, $6000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003D  ; A addr = $3Dxxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3E6000-3E7FFF to VRAM 7000-7FFF
    dw $0000|$2116, $7000  ; VRAM address >> 1.
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003E  ; A addr = $3Exxxx, size = $xx00
    dw $0000|$4356, $0020  ; size = $20xx ($2000), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; SRAM 3F6000-3F61FF to CGRAM 000-1FF
    dw $1000|$2121, $00    ; CGRAM address
    dw $0000|$4350, $2200  ; direction = A->B, byte reg, B addr = $2122
    dw $0000|$4352, $6000  ; A addr = $xx6000
    dw $0000|$4354, $003F  ; A addr = $3Fxxxx, size = $xx00
    dw $0000|$4356, $0002  ; size = $02xx ($0200), unused bank reg = $00.
    dw $1000|$420B, $20    ; Trigger DMA on channel 5
    ; Done
    dw $0000, load_return

load_return:
    %ai16()
    LDA !SRAM_SAVED_STACK : STA $00
    LDA !SRAM_SAVED_STACK+2 : STA $02
    LDA !SRAM_SAVED_SP : TCS

    PEA $8080 : PLB : PLB

    ; rewrite inputs so that holding load won't keep loading, as well as rewriting saving input to loading input
    LDA $5C : EOR !sram_ctrl_save_state : ORA !sram_ctrl_load_state
    STA $5C : STA $5A ;: STA !LK_Current_Inputs

    %a8()
    LDX #$0000 : TXY

  .load_dma_regs
    LDA !SRAM_DMA_BANK,X : STA $4300,X
    INX
    INY : CPY #$000B : BNE .load_dma_regs
    CPX #$007B : BEQ .load_dma_regs_done
    INX #5 : LDY #$0000
    JMP .load_dma_regs

  .load_dma_regs_done
    ; Restore registers AND return.
    JSR post_load_state
    JMP register_restore_return
}

;run_vm:
; Data format: xx xx yy yy
; xxxx = little-endian address to write to .vm's bank
; yyyy = little-endian value to write
; If xxxx has high bit set, read AND discard instead of write.
; If xxxx has bit 12 set ($1000), byte instead of word.
; If yyyy has $DD in the low half, it means that this operation is a byte
; write instead of a word write.  If xxxx is $0000, end the VM.
{
    PEA !SS_BANK : PLB : PLB

  .vm
    %ai16()
    ; Read address to write to
    LDA $0000,X : BEQ .vm_done
    TAY
    INX #2
    ; Check for byte mode
    BIT #$1000 : BEQ .vm_word_mode
    AND #$EFFF : TAY
    %a8()

  .vm_word_mode
    ; Read value
    LDA $0000,X
    INX #2

  .vm_write
    ; Check for read mode (high bit of address)
    CPY #$8000 : BCS .vm_read
    STA $0000,Y
    BRA .vm

  .vm_read
    ; "Subtract" $8000 from y by taking advantage of bank wrapping.
    LDA $8000,Y
    BRA .vm

  .vm_done
    ; A, X AND Y are 16-bit at exit.
    ; Return to caller.  The word in the table after the terminator is the
    ; code address to return to.
    JMP ($0002,x)
}

run_vm:
{
    STZ $02
    PEA !SS_BANK : PLB : PLB

  .vm
    %ai16()
    LDA $0000,X : BEQ .vm_done
    TAY : STA $00
    INX #2
    BIT #$1000 : BEQ .vm_word_mode
    AND #$EFFF : TAY : STA $00
    %a8()

  .vm_word_mode
    LDA $0000,X
    INX #2

  .vm_write
    CPY #$8000 : BCS .vm_read
    STA [$00]
    BRA .vm

  .vm_read
    PHP : %a16()
    TYA : AND #$7FFF : TAY
    PLP
    LDA [$00]
    BRA .vm

  .vm_done
    JMP ($0002,X)
}

print pc, " save.asm end"
