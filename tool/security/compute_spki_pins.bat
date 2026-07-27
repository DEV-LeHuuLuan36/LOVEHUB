@echo off
REM ============================================================================
REM compute_spki_pins.bat — Compute SPKI pins for LoveHub's 5 pinned hosts.
REM
REM HOW TO RUN:
REM   cd d:\Flutter_Source\LOVEHUB
REM   tool\security\compute_spki_pins.bat
REM
REM REQUIREMENTS: Windows 10/11 with certutil (built-in) + PowerShell 5+.
REM NO EXTERNAL DEPENDENCIES NEEDED.
REM
REM OUTPUT: SPKI base64-SHA256 pins printed to console + saved to
REM   %TEMP%\lovehub_spki_pins.txt
REM
REM Copy the BASE64 hash lines (the long string after "Cert hash(sha256):")
REM into android/app/src/main/res/xml/network_security_config.xml
REM under the matching <domain-config>.
REM
REM IMPORTANT: This fetches the LEAF cert only. For the backup pin,
REM   use a second command (documented below).
REM ============================================================================

setlocal

set "OUT=%TEMP%\lovehub_spki_pins.txt"
set "HOSTS=firestore.googleapis.com identitytoolkit.googleapis.com api.groq.com api.cloudinary.com lovehub-push.lehuuluan00.workers.dev"

echo.
echo # LoveHub SPKI Pin Computation                          === LoveHub ===  >> "%OUT%"
echo # Generated: %date% %time%                               === LoveHub ===  >> "%OUT%"
echo.                                                            >> "%OUT%"
echo # INSTRUCTIONS:                                               >> "%OUT%"
echo #   1. Copy the BASE64 line after each hostname.            >> "%OUT%"
echo #   2. Paste into network_security_config.xml.              >> "%OUT%"
echo #   3. For BACKUP pin, run the second command (see below).  >> "%OUT%"
echo.                                                            >> "%OUT%"

for %%H in (%HOSTS%) do (
    echo [%%H] Fetching cert...
    echo.                                                         >> "%OUT%"
    echo [%%H]                                                      >> "%OUT%"
    certutil -urlfetch -verify "https://%%H" 2>nul | findstr /C:"sha256" /C:"Cert hash" >> "%OUT%"
)

echo.
echo ============================================================
echo  PIN COMPUTATION COMPLETE
echo ============================================================
echo.
echo Open %OUT% to see the results.
echo.
echo HOW TO UPDATE network_security_config.xml:
echo   1. Open: android/app/src/main/res/xml/network_security_config.xml
echo   2. For each host, replace the "PRIMARY pin" placeholder
echo      with the BASE64 hash from the output above.
echo   3. For the BACKUP pin, run this PowerShell command:
echo.
echo   powershell -Command "^
     $c = [System.Net.Http.HttpClient]::new(); ^
     $r = $c.GetAsync('https://HOSTNAME').Result; ^
     $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($r.RequestMessage.RequestUri.Host); ^
     $sha = [System.Security.Cryptography.SHA256]::Create(); ^
     [Convert]::ToBase64String($sha.ComputeHash($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)))"
echo.
echo (Replace HOSTNAME with the actual hostname)
echo.

type "%OUT%"

echo.
set /p PAUSE="Press Enter to close..."
