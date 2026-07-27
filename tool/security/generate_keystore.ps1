# generate_keystore.ps1 — Tạo keystore cho LoveHub.
# Chạy: .\tool\security\generate_keystore.ps1
# Tạo keystore tại: android/app/lovehub_upload_keystore.jks
# Sau khi tạo xong, lưu lại thông tin:
#   - Keystore path: android/app/lovehub_upload_keystore.jks
#   - Password: [do bạn nhập]
#   - Alias: lovehub
#   - Password alias: [do bạn nhập]
# ⚠️  Backup keystore + password ở nơi AN TOÀN. Mất = không update app!

param(
    [Parameter(Mandatory=$false)]
    [string]$KeystorePath = "..\android\app\lovehub_upload_keystore.jks",

    [Parameter(Mandatory=$false)]
    [string]$Alias = "lovehub",

    [Parameter(Mandatory=$false)]
    [string]$Dname = "CN=Le Huu Luan, OU=Developer, O=LoveHub, L=Hanoi, ST=Vietnam, C=VN"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

$AbsoluteKeystorePath = Join-Path $ProjectRoot $KeystorePath
$AbsoluteKeystorePath = (Resolve-Path $AbsoluteKeystorePath -ErrorAction SilentlyContinue).Path

if (-not $AbsoluteKeystorePath) {
    # Compute relative path from script location
    $AbsoluteKeystorePath = Join-Path $PSScriptRoot $KeystorePath
}

# Ensure directory exists
$Dir = Split-Path -Parent $AbsoluteKeystorePath
if (-not (Test-Path $Dir)) {
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
}

Write-Host "Keystore path: $AbsoluteKeystorePath" -ForegroundColor Cyan

# Prompt for passwords
Write-Host "Keystore password (min 6 chars): " -NoNewline -ForegroundColor Yellow
$StorePw1 = Read-Host -AsSecureString
$StorePw1Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($StorePw1)
$StorePw1Str = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($StorePw1Bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($StorePw1Bstr)

if ($StorePw1Str.Length -lt 6) {
    Write-Error "Password too short (min 6 characters)."
    exit 1
}

Write-Host "Re-enter keystore password: " -NoNewline -ForegroundColor Yellow
$StorePw2Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString))
$StorePw2Str = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($StorePw2Bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($StorePw2Bstr)

if ($StorePw1Str -ne $StorePw2Str) {
    Write-Error "Passwords don't match."
    exit 1
}

Write-Host "Alias password (min 6 chars, Enter = same as keystore): " -NoNewline -ForegroundColor Yellow
$AliasPw1Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString))
$AliasPw1Str = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($AliasPw1Bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($AliasPw1Bstr)

if ($AliasPw1Str -eq "") {
    $KeyPw = $StorePw1Str
} elseif ($AliasPw1Str.Length -lt 6) {
    Write-Error "Alias password too short (min 6 characters)."
    exit 1
} else {
    Write-Host "Re-enter alias password: " -NoNewline -ForegroundColor Yellow
    $AliasPw2Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString))
    $AliasPw2Str = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($AliasPw2Bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($AliasPw2Bstr)
    if ($AliasPw1Str -ne $AliasPw2Str) {
        Write-Error "Alias passwords don't match."
        exit 1
    }
    $KeyPw = $AliasPw1Str
}

Write-Host "`nGenerating keystore..." -ForegroundColor Cyan

# Build keytool command with stdin for passwords
$keytoolCmd = "keytool"
$args = @(
    "-genkeypair",
    "-v",
    "-storetype", "PKCS12",
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-keystore", $AbsoluteKeystorePath,
    "-alias", $Alias,
    "-dname", $Dname,
    "-keypass", $KeyPw,
    "-storepass", $StorePw1Str
)

$process = Start-Process -FilePath $keytoolCmd -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\keytool_out.txt" -RedirectStandardError "$env:TEMP\keytool_err.txt"

$stdout = Get-Content "$env:TEMP\keytool_out.txt" -Raw -ErrorAction SilentlyContinue
$stderr = Get-Content "$env:TEMP\keytool_err.txt" -Raw -ErrorAction SilentlyContinue

Remove-Item "$env:TEMP\keytool_out.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\keytool_err.txt" -Force -ErrorAction SilentlyContinue

if ($process.ExitCode -ne 0 -or $stderr -match "error|Error|failed") {
    Write-Host "STDERR: $stderr" -ForegroundColor Red
    Write-Host "STDOUT: $stdout" -ForegroundColor Red
    Write-Error "keytool failed with exit code $($process.ExitCode)"
    exit 1
}

Write-Host "Keystore created successfully!" -ForegroundColor Green
Write-Host "  File:    $AbsoluteKeystorePath" -ForegroundColor Cyan
Write-Host "  Alias:   $Alias" -ForegroundColor Cyan
Write-Host "  Expires: $([DateTime]::Now.AddDays(10000).ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. BACKUP: Copy this keystore to a SAFE location (USB + cloud)" -ForegroundColor White
Write-Host "2. Add password to your password manager" -ForegroundColor White
Write-Host "3. Run: flutter build appbundle --release" -ForegroundColor White
Write-Host "4. Upload .aab to Play Console" -ForegroundColor White