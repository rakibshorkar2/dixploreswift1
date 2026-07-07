# DirXplore Native - Project Setup Script for Windows/PowerShell
# Creates Xcode project structure and copies files to proper locations

Write-Host "DirXplore Native Project Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

Write-Host ""
Write-Host "Native Swift project created at: $projectDir" -ForegroundColor Green
Write-Host ""
Write-Host "Project Structure:" -ForegroundColor Yellow
Get-ChildItem -Path $projectDir -Recurse -Directory | ForEach-Object {
    $relative = $_.FullName.Substring($projectDir.Length + 1)
    if ($relative -ne "") {
        Write-Host "  $relative/" -ForegroundColor DarkGray
    }
}
Write-Host ""
Write-Host "Source Files Created: $( (Get-ChildItem -Path $projectDir -Recurse -File -Filter "*.swift").Count )" -ForegroundColor Green
Write-Host "Test Files: $( (Get-ChildItem -Path $projectDir -Recurse -File -Filter "*Tests*.swift").Count )" -ForegroundColor Green
Write-Host ""
Write-Host "To build the project:" -ForegroundColor Cyan
Write-Host "  Option 1: Open in Xcode" -ForegroundColor White
Write-Host "    1. Open Xcode on macOS" -ForegroundColor Gray
Write-Host "    2. File > New > Project > iOS > App" -ForegroundColor Gray
Write-Host "    3. Name: DirXplore, Interface: SwiftUI, Language: Swift, iOS 18.0" -ForegroundColor Gray
Write-Host "    4. Drag all files from 'DirXploreNative' into the project" -ForegroundColor Gray
Write-Host "    5. Add Info.plist and entitlements from Resources/" -ForegroundColor Gray
Write-Host "    6. Add WidgetExtension target for Live Activities" -ForegroundColor Gray
Write-Host "    7. Add Yams package dependency (https://github.com/jpsim/Yams)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Option 2: Use Swift Package Manager (macOS)" -ForegroundColor White
Write-Host "    cd DirXploreNative" -ForegroundColor Gray
Write-Host "    swift build" -ForegroundColor Gray
Write-Host ""
Write-Host "  Option 3: Use XcodeGen (macOS)" -ForegroundColor White
Write-Host "    brew install xcodegen" -ForegroundColor Gray
Write-Host "    cd DirXploreNative && xcodegen generate" -ForegroundColor Gray
Write-Host "    open DirXplore.xcodeproj" -ForegroundColor Gray
