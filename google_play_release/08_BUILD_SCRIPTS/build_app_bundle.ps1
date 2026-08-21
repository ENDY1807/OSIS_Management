# PowerShell Script Build App Bundle untuk Google Play Store
$ErrorActionPreference = "Stop"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "   BUILD ANDROID APP BUNDLE (.AAB) UNTUK GOOGLE PLAY STORE           " -ForegroundColor Cyan
Write-Host "   Aplikasi: OSIS Management (id.sch.baknus.osisjurnal)              " -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $projectRoot

Write-Host "`n[1/3] Membersihkan build lama (flutter clean)..." -ForegroundColor Yellow
flutter clean

Write-Host "`n[2/3] Mengambil dependensi (flutter pub get)..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[3/3] Membangun Android App Bundle Release (flutter build appbundle --release)..." -ForegroundColor Yellow
flutter build appbundle --release

$sourceAab = Join-Path $projectRoot "build\app\outputs\bundle\release\app-release.aab"
$outDir = Join-Path $projectRoot "google_play_release\output_aab"
$destAab = Join-Path $outDir "OSIS_Management_Release_v1.0.0.aab"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

if (Test-Path $sourceAab) {
    Copy-Item -Path $sourceAab -Destination $destAab -Force
    $fileItem = Get-Item $destAab
    $sizeMb = [math]::Round($fileItem.Length / 1MB, 2)
    
    Write-Host "`n=====================================================================" -ForegroundColor Green
    Write-Host "[BERHASIL] File App Bundle siap diupload ke Google Play Console!" -ForegroundColor Green
    Write-Host "Lokasi File : $destAab" -ForegroundColor Green
    Write-Host "Ukuran File : $sizeMb MB" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Green
} else {
    Write-Host "`n[!] File output tidak ditemukan di $sourceAab" -ForegroundColor Red
}
