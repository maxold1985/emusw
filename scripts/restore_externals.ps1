$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$source = Join-Path $env:TEMP 'emusw-yuzu-archive'
if (!(Test-Path (Join-Path $source '.git'))) {
    git clone --depth 1 https://github.com/SnowZucc/yuzu-archive.git $source
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao clonar yuzu-archive' }
}
$modules = @(
    'externals/enet', 'externals/cubeb', 'externals/sirit',
    'externals/opus', 'externals/Vulkan-Headers',
    'externals/Vulkan-Utility-Libraries', 'externals/VulkanMemoryAllocator',
    'externals/simpleini', 'externals/xbyak', 'externals/dynarmic',
    'externals/mbedtls', 'externals/libusb/libusb',
    'externals/discord-rpc', 'externals/SDL', 'externals/nx_tzdb/tzdb_to_nx'
)
$overrides = @{
    sirit = 'https://github.com/ReinUsesLisp/sirit.git'
    dynarmic = 'https://github.com/azahar-emu/dynarmic.git'
    mbedtls = 'https://github.com/Mbed-TLS/mbedtls.git'
    'discord-rpc' = 'https://github.com/discord/discord-rpc.git'
}
foreach ($name in $overrides.Keys) {
    git -C $source config -f .gitmodules "submodule.$name.url" $overrides[$name]
    if ($LASTEXITCODE -ne 0) { throw "Falha ao configurar $name" }
}
git -C $source submodule sync -- externals/sirit externals/dynarmic externals/mbedtls externals/discord-rpc
if ($LASTEXITCODE -ne 0) { throw 'Falha ao sincronizar submodulos' }
foreach ($module in $modules) {
    $target = Join-Path (Get-Location).Path $module
    $origin = Join-Path $source $module
    if ((Test-Path (Join-Path $target 'CMakeLists.txt')) -and
        ($module -ne 'externals/sirit' -or (Test-Path (Join-Path $target 'externals/SPIRV-Headers/CMakeLists.txt'))) -and
        ($module -ne 'externals/cubeb' -or (Test-Path (Join-Path $target 'cmake/sanitizers-cmake/cmake/FindSanitizers.cmake')))) {
        continue
    }
    git -C $source submodule update --init --depth 1 -- $module
    if ($LASTEXITCODE -ne 0) { throw "Falha ao baixar $module" }
    if ($module -eq 'externals/sirit') {
        git -C $origin submodule update --init --recursive --depth 1
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao baixar SPIRV-Headers' }
    }
    if ($module -eq 'externals/cubeb') {
        git -C $origin submodule update --init --recursive --depth 1 -- cmake/sanitizers-cmake
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao baixar sanitizers-cmake' }
    }
    New-Item -ItemType Directory -Force $target | Out-Null
    & robocopy $origin $target /E /XF .git /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -gt 7) { throw "Falha ao copiar $module" }
}
Write-Host '[OK] Dependencias externas restauradas.'
