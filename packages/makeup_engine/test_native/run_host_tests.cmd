@echo off
rem Compila y corre los tests de host del motor (C++ sin GL) con MSVC + Ninja.
rem Uso: packages\makeup_engine\test_native\run_host_tests.cmd [filtro]
setlocal
set "HERE=%~dp0"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo No se encontro vswhere.exe: hace falta Visual Studio con C++.
  exit /b 1
)
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSDIR=%%i"
if not defined VSDIR (
  echo Visual Studio no tiene las herramientas de C++ instaladas.
  exit /b 1
)
call "%VSDIR%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul || exit /b 1
set "BUILD=%HERE%build"
cmake -S "%HERE%." -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Debug >nul || exit /b 1
cmake --build "%BUILD%" || exit /b 1
"%BUILD%\makeup_engine_host_tests.exe" %*
