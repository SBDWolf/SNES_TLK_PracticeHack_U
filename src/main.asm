
hirom

; First includes for assembler
incsrc defines.asm
incsrc macros.asm
table ../resources/text2hex.tbl
; Order matters less from here on


; Expand the ROM to 4MB
; Free space starts at $F00000
org $FFFFFF
    db $00

; Set cart type
org $00FFD6 : GameHeader_CartridgeType:
    db $02 ; ROM, RAM and battery

; Set SRAM size
; SRAM starts at $6000 and ends at $7FFF, banks $20-3F
org $00FFD8 : GameHeader_SRAMSize:
if !FEATURE_SAVESTATES
    db $08 ; 256kb for SD2/FXPAK and select emulators, banks $20-3F, $6000-7FFF
else
    db $05 ; 64kb max for Virtual Console support, banks $30-33, $6000-7FFF
endif

incsrc freespace.asm
incsrc init.asm ; Bank $FF
incsrc timer.asm ; Bank $F1
incsrc controller.asm ; Bank $F2
incsrc save.asm ; Bank $F3
incsrc menu.asm ; Bank $F0
incsrc mainmenu.asm ; Bank $F0
incsrc misc.asm ; Bank $F5

;if !DEV_BUILD
; restrict to dev builds when stable?
incsrc crash.asm ; Bank $F4
;endif

%printfreespace()
print "~ asar task completed."
