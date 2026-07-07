# DirXplore Native - Project Setup Script for Windows/PowerShell
# Creates Xcode project structure and copies files to proper locations

Write-Host "DirXplore Native Project Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host ""
Write-Host "Native Swift project with LibTorrent integration" -ForegroundColor Green
Write-Host ""
Write-Host "Project Structure:" -ForegroundColor Yellow
Get-ChildItem -Path $projectDir -Recurse -Directory | ForEach-Object {
    $relative = $_.FullName.Substring($projectDir.Length + 1)
    if ($relative -ne "" -and $relative -notlike "Thirdparty*" -and $relative -notlike ".git*") {
        Write-Host "  $relative/" -ForegroundColor DarkGray
    }
}
Write-Host ""
Write-Host "Source Files Created: $( (Get-ChildItem -Path $projectDir -Recurse -File -Filter "*.swift").Count )" -ForegroundColor Green
Write-Host "Test Files: $( (Get-ChildItem -Path $projectDir -Recurse -File -Filter "*Tests*.swift").Count )" -ForegroundColor Green
Write-Host "LibTorrent ObjC/C++ Files: $( (Get-ChildItem -Path $projectDir\LibTorrent -Recurse -File -Include "*.m", "*.mm", "*.h").Count )" -ForegroundColor Green
Write-Host ""
Write-Host "To build the project (macOS only):" -ForegroundColor Cyan
Write-Host "  Option 1: Using XcodeGen (recommended)" -ForegroundColor White
Write-Host "    brew install xcodegen" -ForegroundColor Gray
Write-Host "    ./setup.sh" -ForegroundColor Gray
Write-Host "    open DirXplore.xcodeproj" -ForegroundColor Gray
Write-Host ""
Write-Host "  Option 2: Manual setup in Xcode" -ForegroundColor White
Write-Host "    1. Open Xcode, create new iOS App project (SwiftUI, iOS 18.0)" -ForegroundColor Gray
Write-Host "    2. Drag all Swift source folders into the project" -ForegroundColor Gray
Write-Host "    3. Drag LibTorrent/ folder into the project" -ForegroundColor Gray
Write-Host "    4. Add all .m, .mm, .swift files from LibTorrent to target" -ForegroundColor Gray
Write-Host "    5. Set Bridging Header to 'LibTorrent/Bridging-Header.h'" -ForegroundColor Gray
Write-Host "    6. Add Thirdparty/libtorrent/include to Header Search Paths" -ForegroundColor Gray
Write-Host "    7. Link CoreFoundation.framework, SystemConfiguration.framework, libiconv.tbd" -ForegroundColor Gray
Write-Host "    8. Set C++ Standard Library to libc++ and C++ Standard to C++14" -ForegroundColor Gray
Write-Host "    9. Add Yams package (https://github.com/jpsim/Yams)" -ForegroundColor Gray
Write-Host "    10. Run 'make.sh' to build C++ libtorrent library before building" -ForegroundColor Gray
Write-Host "    11. Add WidgetExtension target for Live Activities" -ForegroundColor Gray
Write-Host ""
Write-Host "Building libtorrent C++ library:" -ForegroundColor Yellow
Write-Host "  Before first build, run: bash make.sh" -ForegroundColor White
Write-Host "  This requires: cmake, Xcode command line tools" -ForegroundColor Gray
Write-Host "  The script builds the C++ libtorrent static library via CMake + Xcode" -ForegroundColor Gray
