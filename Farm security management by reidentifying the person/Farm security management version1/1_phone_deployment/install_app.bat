@echo off
title Kisan App Installer
echo =====================================================
echo      KISAN MOBILE APP DIRECT USB INSTALLER
echo =====================================================
echo.
echo Please verify the following:
echo 1. USB Debugging is ENABLED on your phone (in Settings - Developer Options).
echo 2. The phone is connected to the PC via USB.
echo 3. You have accepted the "Allow USB Debugging?" prompt on your phone screen.
echo.
pause
echo.
echo [*] Searching for connected device...
"C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
echo.
echo [*] Installing app-release.apk to your phone...
"C:\Users\GITAM\AppData\Local\Android\Sdk\platform-tools\adb.exe" install -r "build\app\outputs\flutter-apk\app-release.apk"
if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] The app has been successfully installed on your phone!
) else (
    echo.
    echo [ERROR] Installation failed.
    echo Please make sure your phone screen is unlocked and you allowed the USB debugging prompt.
)
echo.
pause
