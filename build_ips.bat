@echo off

echo The Lion King Practice Hack by SBDWolf and InsaneFirebat
cd resources

echo Creating dummy ROMs: 00 and FF filled .sfc files
python create_dummies.py 00.sfc ff.sfc

echo Patching dummies
copy *.sfc ..\build
..\tools\asar\asar.exe --no-title-check -DDEV_BUILD=0 ..\src\main.asm ..\build\00.sfc
..\tools\asar\asar.exe --no-title-check -DDEV_BUILD=0 ..\src\main.asm ..\build\ff.sfc

echo Creating IPS patch from dummies
python create_ips.py ..\build\00.sfc ..\build\ff.sfc ..\build\LionKing_Practice_2.0.X.ips

echo Patching dummies (savestates enabled)
copy *.sfc ..\build
..\tools\asar\asar.exe --no-title-check -DDEV_BUILD=0 -DFEATURE_SAVESTATES=1 ..\src\main.asm ..\build\00.sfc
..\tools\asar\asar.exe --no-title-check -DDEV_BUILD=0 -DFEATURE_SAVESTATES=1 ..\src\main.asm ..\build\ff.sfc

echo Creating IPS patch from dummies
python create_ips.py ..\build\00.sfc ..\build\ff.sfc ..\build\LionKing_Practice_Savestates_2.0.X.ips

echo Cleaning up dummies
del 00.sfc ff.sfc ..\build\00.sfc ..\build\ff.sfc
cd ..
PAUSE
