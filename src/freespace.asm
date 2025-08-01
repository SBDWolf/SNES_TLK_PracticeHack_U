
; Original design by cout https://github.com/cout/baby_metroid/blob/main/src/freespace.asm

; Assign start of freespace per bank
; Only one chunk allowed per bank
; Ommited banks have less than $10 bytes of freespace
!START_FREESPACE_C0 = $C0FEC8 ; $E4 bytes
!START_FREESPACE_C1 = $C1FF73 ; $8D bytes
!START_FREESPACE_C3 = $C3FEA0 ; $160 bytes
!START_FREESPACE_C4 = $C4FF92 ; $6E bytes
!START_FREESPACE_C5 = $C5FF33 ; $CD bytes
!START_FREESPACE_C6 = $C6FF70 ; $90 bytes
!START_FREESPACE_CA = $CAFFE9 ; $17 bytes
!START_FREESPACE_D0 = $D0FFE8 ; $18 bytes
!START_FREESPACE_DA = $DAFFE7 ; $19 bytes
!START_FREESPACE_DB = $DBFFEA ; $16 bytes
!START_FREESPACE_DD = $DDFFF0 ; $10 bytes
!START_FREESPACE_DE = $DEFFDD ; $23 bytes
!START_FREESPACE_DF = $DFFFD5 ; $2B bytes
!START_FREESPACE_E0 = $E0FFDA ; $26 bytes
!START_FREESPACE_E3 = $E3FFDF ; $21 bytes
!START_FREESPACE_E4 = $E4FFED ; $13 bytes
!START_FREESPACE_E8 = $E8FFEF ; $11 bytes
!START_FREESPACE_E9 = $E9FFEB ; $15 bytes
!START_FREESPACE_EA = $EAFFDD ; $23 bytes
!START_FREESPACE_ED = $EDFFEF ; $11 bytes
!START_FREESPACE_EF = $EFF202 ; $DFE bytes
!START_FREESPACE_F0 = $F00000
!START_FREESPACE_F1 = $F10000
!START_FREESPACE_F2 = $F20000
!START_FREESPACE_F3 = $F30000
!START_FREESPACE_F4 = $F40000
!START_FREESPACE_F5 = $F50000
!START_FREESPACE_F6 = $F60000
!START_FREESPACE_F7 = $F70000
!START_FREESPACE_F8 = $F80000
!START_FREESPACE_F9 = $F90000
!START_FREESPACE_FA = $FA0000
!START_FREESPACE_FB = $FB0000
!START_FREESPACE_FC = $FC0000
!START_FREESPACE_FD = $FD0000
!START_FREESPACE_FE = $FE0000
!START_FREESPACE_FF = $FF0000

; These defines will be reassigned by the endfree macro
; This leaves our starting location untouched for later evaluation
!FREESPACE_C0 = !START_FREESPACE_C0
!FREESPACE_C1 = !START_FREESPACE_C1
!FREESPACE_C3 = !START_FREESPACE_C3
!FREESPACE_C4 = !START_FREESPACE_C4
!FREESPACE_C5 = !START_FREESPACE_C5
!FREESPACE_C6 = !START_FREESPACE_C6
!FREESPACE_CA = !START_FREESPACE_CA
!FREESPACE_D0 = !START_FREESPACE_D0
!FREESPACE_DA = !START_FREESPACE_DA
!FREESPACE_DB = !START_FREESPACE_DB
!FREESPACE_DD = !START_FREESPACE_DD
!FREESPACE_DE = !START_FREESPACE_DE
!FREESPACE_DF = !START_FREESPACE_DF
!FREESPACE_E0 = !START_FREESPACE_E0
!FREESPACE_E3 = !START_FREESPACE_E3
!FREESPACE_E4 = !START_FREESPACE_E4
!FREESPACE_E8 = !START_FREESPACE_E8
!FREESPACE_E9 = !START_FREESPACE_E9
!FREESPACE_EA = !START_FREESPACE_EA
!FREESPACE_ED = !START_FREESPACE_ED
!FREESPACE_EF = !START_FREESPACE_EF
!FREESPACE_F0 = !START_FREESPACE_F0
!FREESPACE_F1 = !START_FREESPACE_F1
!FREESPACE_F2 = !START_FREESPACE_F2
!FREESPACE_F3 = !START_FREESPACE_F3
!FREESPACE_F4 = !START_FREESPACE_F4
!FREESPACE_F5 = !START_FREESPACE_F5
!FREESPACE_F6 = !START_FREESPACE_F6
!FREESPACE_F7 = !START_FREESPACE_F7
!FREESPACE_F8 = !START_FREESPACE_F8
!FREESPACE_F9 = !START_FREESPACE_F9
!FREESPACE_FA = !START_FREESPACE_FA
!FREESPACE_FB = !START_FREESPACE_FB
!FREESPACE_FC = !START_FREESPACE_FC
!FREESPACE_FD = !START_FREESPACE_FD
!FREESPACE_FE = !START_FREESPACE_FE
!FREESPACE_FF = !START_FREESPACE_FF

; Assign end of freespace per bank
; Set for freespace that doesn't end at the bank border
!END_FREESPACE_C0 = $C0FFAC
!END_FREESPACE_C1 = $C10000+$10000
!END_FREESPACE_C3 = $C30000+$10000
!END_FREESPACE_C4 = $C40000+$10000
!END_FREESPACE_C5 = $C50000+$10000
!END_FREESPACE_C6 = $C60000+$10000
!END_FREESPACE_CA = $CA0000+$10000
!END_FREESPACE_D0 = $D00000+$10000
!END_FREESPACE_DA = $DA0000+$10000
!END_FREESPACE_DB = $DB0000+$10000
!END_FREESPACE_DD = $DD0000+$10000
!END_FREESPACE_DE = $DE0000+$10000
!END_FREESPACE_DF = $DF0000+$10000
!END_FREESPACE_E0 = $E00000+$10000
!END_FREESPACE_E3 = $E30000+$10000
!END_FREESPACE_E4 = $E40000+$10000
!END_FREESPACE_E8 = $E80000+$10000
!END_FREESPACE_E9 = $E90000+$10000
!END_FREESPACE_EA = $EA0000+$10000
!END_FREESPACE_ED = $ED0000+$10000
!END_FREESPACE_EF = $EF0000+$10000
!END_FREESPACE_F0 = $F00000+$10000
!END_FREESPACE_F1 = $F10000+$10000
!END_FREESPACE_F2 = $F20000+$10000
!END_FREESPACE_F3 = $F30000+$10000
!END_FREESPACE_F4 = $F40000+$10000
!END_FREESPACE_F5 = $F50000+$10000
!END_FREESPACE_F6 = $F60000+$10000
!END_FREESPACE_F7 = $F70000+$10000
!END_FREESPACE_F8 = $F80000+$10000
!END_FREESPACE_F9 = $F90000+$10000
!END_FREESPACE_FA = $FA0000+$10000
!END_FREESPACE_FB = $FB0000+$10000
!END_FREESPACE_FC = $FC0000+$10000
!END_FREESPACE_FD = $FD0000+$10000
!END_FREESPACE_FE = $FE0000+$10000
!END_FREESPACE_FF = $1000000-1

; Allows us to setup warnings for mishandled macros
!FREESPACE_BANK = -1

macro startfree(bank)
; Allows us to assign freespace without gaps from different files
assert !FREESPACE_BANK < 0, "You forgot to close out bank !FREESPACE_BANK"
org !FREESPACE_<bank>
!FREESPACE_BANK = $<bank>
endmacro

macro endfree(bank)
; Used to close out an org and track the next free byte
assert !FREESPACE_BANK >= 0, "No matching startfree(<bank>)"
assert $<bank> = !FREESPACE_BANK, "You closed out the wrong bank. (Check bank !FREESPACE_BANK)"
!FREESPACE_COUNTER_<bank> ?= 0
FreespaceLabel<bank>_!FREESPACE_COUNTER_<bank>:
!FREESPACE_<bank> := FreespaceLabel<bank>_!FREESPACE_COUNTER_<bank>
!FREESPACE_COUNTER_<bank> #= !FREESPACE_COUNTER_<bank>+1
!FREESPACE_BANK = -1
warnpc !END_FREESPACE_<bank>
endmacro

macro printfreespacebank(bank)
; Print some numbers about our freespace usage
org !FREESPACE_<bank>
!FREESPACE_COUNTER_<bank> ?= 0
if !FREESPACE_COUNTER_<bank>
print "Bank $<bank> ended at $", pc, " with $", hex(!END_FREESPACE_<bank>-!FREESPACE_<bank>), " bytes remaining"
endif
endmacro

macro printfreespace()
; Hide this long list in a single macro
%printfreespacebank(C0)
%printfreespacebank(C1)
%printfreespacebank(C3)
%printfreespacebank(C4)
%printfreespacebank(C5)
%printfreespacebank(C6)
%printfreespacebank(CA)
%printfreespacebank(D0)
%printfreespacebank(DA)
%printfreespacebank(DB)
%printfreespacebank(DD)
%printfreespacebank(DE)
%printfreespacebank(DF)
%printfreespacebank(E0)
%printfreespacebank(E3)
%printfreespacebank(E4)
%printfreespacebank(E8)
%printfreespacebank(E9)
%printfreespacebank(EA)
%printfreespacebank(ED)
%printfreespacebank(EF)
%printfreespacebank(F0)
%printfreespacebank(F1)
%printfreespacebank(F2)
%printfreespacebank(F3)
%printfreespacebank(F4)
%printfreespacebank(F5)
%printfreespacebank(F6)
%printfreespacebank(F7)
%printfreespacebank(F8)
%printfreespacebank(F9)
%printfreespacebank(FA)
%printfreespacebank(FB)
%printfreespacebank(FC)
%printfreespacebank(FD)
%printfreespacebank(FE)
%printfreespacebank(FF)
endmacro

