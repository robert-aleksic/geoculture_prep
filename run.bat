@echo off
call exif.bat 
echo compilng prep...
call compile.bat
prep.exe
call copyrenamed.bat