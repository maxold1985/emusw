@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "ROOT=%CD%"
set "VCPKG_ROOT=%ROOT%\externals\vcpkg"
set "VCPKG_BINARY_SOURCES=clear;files,%ROOT%\.vcpkg-binary-cache,readwrite"
set "VCPKG_KEEP_ENV_VARS=PKG_CONFIG"
set "FFMPEG_DIR=%VCPKG_ROOT%\installed\x64-windows"
set "JOBS=2"
if not "%~1"=="" set "JOBS=%~1"

where cmake >nul 2>&1 || (echo [ERRO] Instale CMake e adicione ao PATH. & exit /b 1)
where git >nul 2>&1 || (echo [ERRO] Instale Git para Windows. & exit /b 1)
where nasm >nul 2>&1
if errorlevel 1 (
  echo [INFO] NASM nao encontrado. Tentando instalar pelo winget...
  where winget >nul 2>&1
  if not errorlevel 1 (
    winget install --id NASM.NASM --exact --accept-package-agreements --accept-source-agreements
  ) else (
    echo [INFO] winget indisponivel. Tentando Chocolatey...
    where choco >nul 2>&1
    if errorlevel 1 (
      echo [ERRO] Instale NASM manualmente ou instale winget/Chocolatey.
      exit /b 1
    )
    choco install nasm -y --no-progress
  )
  set "NASM_DIR="
  if exist "%ProgramFiles%\NASM\nasm.exe" set "NASM_DIR=%ProgramFiles%\NASM"
  if exist "%ProgramFiles(x86)%\NASM\nasm.exe" set "NASM_DIR=%ProgramFiles(x86)%\NASM"
  if exist "C:\ProgramData\chocolatey\bin\nasm.exe" set "NASM_DIR=C:\ProgramData\chocolatey\bin"
  if defined NASM_DIR set "PATH=%NASM_DIR%;%PATH%"
  where nasm >nul 2>&1
  if errorlevel 1 (
    echo [ERRO] NASM nao encontrado apos instalacao. Abra um novo terminal ou verifique PATH.
    exit /b 1
  )
)
nasm -v
where glslangValidator >nul 2>&1 || (echo [ERRO] Instale glslangValidator e adicione ao PATH. & exit /b 1)

if not exist "%VCPKG_ROOT%\vcpkg.exe" (
  if not exist "%VCPKG_ROOT%\bootstrap-vcpkg.bat" (
    if exist "%VCPKG_ROOT%" (
      echo [ERRO] externals\vcpkg existe mas nao contem bootstrap-vcpkg.bat
      exit /b 1
    )
    git clone https://github.com/microsoft/vcpkg.git "%VCPKG_ROOT%" || exit /b 1
    git -C "%VCPKG_ROOT%" checkout a42af01b72c28a8e1d7b48107b33e4f286a55ef6 || exit /b 1
  )
  call "%VCPKG_ROOT%\bootstrap-vcpkg.bat" -disableMetrics || exit /b 1
)

if not exist "externals\sirit\CMakeLists.txt" (
  echo [INFO] Restaurando dependencias do Yuzu original...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\restore_externals.ps1"
  if errorlevel 1 exit /b 1
)
if not exist "externals\sirit\externals\SPIRV-Headers\CMakeLists.txt" (
  echo [INFO] Restaurando submodulos internos...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\restore_externals.ps1"
  if errorlevel 1 exit /b 1
)

if not exist ".vcpkg-binary-cache" mkdir ".vcpkg-binary-cache"
echo [1/3] Instalando dependencias vcpkg do manifesto...
"%VCPKG_ROOT%\vcpkg.exe" install --triplet x64-windows || exit /b 1
if not exist "%FFMPEG_DIR%\include\libavcodec\avcodec.h" (echo [ERRO] FFmpeg avcodec ausente. & exit /b 1)
if not exist "%FFMPEG_DIR%\include\libswscale\swscale.h" (echo [ERRO] FFmpeg swscale ausente. & exit /b 1)

echo [2/3] Configurando Visual Studio 2022 x64...
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 ^
  -DENABLE_QT=OFF ^
  -DENABLE_SDL2=ON ^
  -DYUZU_USE_BUNDLED_SDL2=OFF ^
  -DENABLE_WEB_SERVICE=OFF ^
  -DYUZU_CHECK_SUBMODULES=OFF ^
  -DYUZU_USE_BUNDLED_FFMPEG=OFF ^
  -DYUZU_TESTS=OFF ^
  -DYUZU_ROOM=OFF ^
  -DYUZU_USE_BUNDLED_VCPKG=ON ^
  -DCMAKE_POLICY_DEFAULT_CMP0167=OLD
if errorlevel 1 exit /b 1

echo [3/3] Compilando Release x64 com %JOBS% processos...
cmake --build build --config Release --parallel %JOBS%
if errorlevel 1 exit /b 1
echo [OK] Compilacao concluida. Procure os executaveis em build\.
exit /b 0
