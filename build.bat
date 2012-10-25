@echo off
dmd build.d lib/ini.d -ofbuild
build.exe
del build.exe
del build.map
del build.obj
pause