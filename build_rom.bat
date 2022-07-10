@echo off

echo Building The Lion King Practice Hack

cd build
echo Building and pre-patching saveless version
copy LionKing.sfc LionKing_Practice_1.0.X.sfc && ..\tools\asar\asar.exe --no-title-check ..\src\main.asm LionKing_Practice_1.0.X.sfc && cd ..

cd build
echo Building and pre-patching savestate version
copy LionKing.sfc LionKing_Practice_Savestates_1.0.X.sfc && ..\tools\asar\asar.exe --no-title-check -DFEATURE_SAVESTATES=1 ..\src\main.asm LionKing_Practice_Savestates_1.0.X.sfc && cd ..

PAUSE
