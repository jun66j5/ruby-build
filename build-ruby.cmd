@setlocal
@set _VSROOT=
@for /f "tokens=* usebackq" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -products * -requires Microsoft.Component.MSBuild -property installationPath -latest`) do set "_VSROOT=%%i"
call "%_VSROOT%\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%
powershell.exe -file %~dp0build-ruby.ps1 || exit /b 1
@endlocal
