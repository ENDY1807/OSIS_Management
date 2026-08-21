@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo    BUILD ANDROID APP BUNDLE (.AAB) UNTUK GOOGLE PLAY STORE
echo    Aplikasi: OSIS Management (id.sch.baknus.osisjurnal)
echo =====================================================================
echo.

cd /d "%~dp0..\.."

echo [1/3] Membersihkan build lama (flutter clean)...
call flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo [!] Gagal saat menjalankan flutter clean.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Mengambil dependensi (flutter pub get)...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [!] Gagal saat menjalankan flutter pub get.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Membangun Android App Bundle Release (flutter build appbundle --release)...
call flutter build appbundle --release
if %ERRORLEVEL% NEQ 0 (
    echo [!] Gagal saat build App Bundle. Periksa error di atas.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ---------------------------------------------------------------------
echo Menyalin file .aab ke folder google_play_release\output_aab...

if not exist "google_play_release\output_aab" mkdir "google_play_release\output_aab"

set "SOURCE_AAB=build\app\outputs\bundle\release\app-release.aab"
set "DEST_AAB=google_play_release\output_aab\OSIS_Management_Release_v1.0.0.aab"

if exist "%SOURCE_AAB%" (
    copy /Y "%SOURCE_AAB%" "%DEST_AAB%" > nul
    echo.
    echo =====================================================================
    echo [BERHASIL] File App Bundle siap diupload ke Google Play Console!
    echo Lokasi File: %DEST_AAB%
    echo =====================================================================
) else (
    echo [!] File build output tidak ditemukan di %SOURCE_AAB%
)

echo.
pause
