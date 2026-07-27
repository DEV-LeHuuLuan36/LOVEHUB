# LoveHub SPKI Pin Computation
# Run: powershell -ExecutionPolicy Bypass -File tool/security/compute_spki_pins.ps1
# Output: saved to $env:TEMP\lovehub_pins.txt

$hosts = @(
    'firestore.googleapis.com',
    'identitytoolkit.googleapis.com',
    'api.groq.com',
    'api.cloudinary.com',
    'lovehub-push.lehuuluan00.workers.dev'
)

$out = "$env:TEMP\lovehub_pins.txt"
Remove-Item $out -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'LoveHub SPKI Pin Computation' -ForegroundColor Cyan
Write-Host ''

Add-Content -Path $out -Value "# LoveHub SPKI Pin Computation"
Add-Content -Path $out -Value "# Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $out -Value ''

foreach ($h in $hosts) {
    Write-Host "Processing: $h"
    Add-Content -Path $out -Value "[$h]"
    try {
        $tcp = [System.Net.Sockets.TcpClient]::new($h, 443)
        $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream())
        $ssl.AuthenticateAsClient($h)
        $cert = $ssl.RemoteCertificate
        $tcp.Close()

        if ($cert) {
            $cert2 = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert)
            $der = $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hash = $sha.ComputeHash($der)
            $pin = [Convert]::ToBase64String($hash)
            Write-Host "  PIN: $pin" -ForegroundColor Green
            Add-Content -Path $out -Value "  PRIMARY=$pin"
        } else {
            Write-Host "  NO CERT" -ForegroundColor Red
            Add-Content -Path $out -Value "  ERROR: no cert"
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Add-Content -Path $out -Value "  ERROR: $($_.Exception.Message)"
    }
    Write-Host ''
}

Write-Host "Done. Output: $out" -ForegroundColor Cyan