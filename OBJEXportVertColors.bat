@echo off

if "%~1" == "" (
  echo �����̃E�B���h�E����āA���̃o�b�`�t�@�C����.aqo�t�@�C�����h���b�O���h���b�v���Ă��������B
  pause
  exit /b
)

echo:
"%~dp0NIFLTool.exe" -obj "%~dp0%~n1.obj" "%1"
echo:

