@echo off

if "%~1" == "" (
  echo ※このウィンドウを閉じて、このバッチファイルに.aqoファイルをドラッグ＆ドロップしてください。
  pause
  exit /b
)

echo:
"%~dp0NIFLTool.exe" -obj "%~dp0%~n1.obj" "%1"
echo:

