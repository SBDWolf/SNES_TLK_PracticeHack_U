
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


incsrc init.asm ; $FF0000
incsrc timer.asm ; $F10000
incsrc controller.asm ; $F20000
incsrc save.asm ; $F30000
incsrc menu.asm ; $F00000
incsrc mainmenu.asm ; $F08000
incsrc misc.asm ; $F50000

;if !DEV_BUILD
; restrict to dev builds when stable?
incsrc crash.asm ; $F40000
;endif

print "~ asar task completed."
