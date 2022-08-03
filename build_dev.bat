@echo off

echo Building LionKing Practice Hack

cd build
echo Building and pre-patching savestate dev build
copy LionKing.sfc aaaa_LionKingPrac.sfc && ..\tools\asar\asar.exe --no-title-check -DDEV_BUILD=1 -DFEATURE_SAVESTATES=1 --symbols=wla --symbols-path=LionKing_Practice.sym ..\src\main.asm aaaa_LionKingPrac.sfc && cd ..

PAUSE
