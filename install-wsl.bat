@echo off

goto default

:default
powershell -ExecutionPolicy ByPass -command "& { . .\install-wsl.ps1; Install-WSLInteractive }"

:end