param(
    [Parameter(Mandatory=$true)]
    [string]$Url,

    [ValidateSet("auto","http","tls")]
    [string]$Mode = "auto"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Trust Self-Signed Certificate Tool (Windows)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Error: Please run PowerShell as Administrator!" -ForegroundColor Red
    exit 1
}

# Parse URL
$uri = [System.Uri]$Url
$targetHost = $uri.Host
$port = if ($uri.Port -ne -1) { $uri.Port } else { 443 }

Write-Host "Target: $Url"
Write-Host "Host: $targetHost"
Write-Host "Port: $port"
Write-Host "Mode: $Mode (auto/http/tls)"
Write-Host ""

$certPath = Join-Path $env:TEMP "$targetHost.cer"

function Get-CertFromHttp {
    param([string]$TargetHost)

    $httpUrl = "http://$TargetHost`:32000/ssl/ca.crt"
    Write-Host "Trying HTTP download: $httpUrl" -ForegroundColor DarkYellow

    $tmpPath = Join-Path $env:TEMP "$TargetHost.http.download"

    try {
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            & curl.exe -fsSL $httpUrl -o $tmpPath | Out-Null
        } else {
            Invoke-WebRequest -Uri $httpUrl -OutFile $tmpPath -UseBasicParsing
        }

        if (-not (Test-Path $tmpPath) -or ((Get-Item $tmpPath).Length -le 0)) {
            throw "Downloaded file is empty"
        }

        $raw = [System.IO.File]::ReadAllBytes($tmpPath)

        try {
            $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($raw)
        } catch {
            $text = Get-Content -Raw -LiteralPath $tmpPath
            if ($text -match "BEGIN CERTIFICATE") {
                $b64 = ($text -replace "-----BEGIN CERTIFICATE-----","" `
                              -replace "-----END CERTIFICATE-----","" `
                              -replace "\s","").Trim()
                $der = [Convert]::FromBase64String($b64)
                $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($der)
            } else {
                throw "Unknown certificate format (not DER, not PEM)."
            }
        }

        $bytes = $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($certPath, $bytes)

        return $cert2
    }
    finally {
        if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue }
    }
}

function Get-CertFromTls {
    param([string]$TargetHost, [int]$Port)

    Write-Host "Trying TLS fetch from: $TargetHost`:$Port" -ForegroundColor DarkYellow

    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = `
            [System.Net.SecurityProtocolType]::Tls12 -bor `
            [System.Net.SecurityProtocolType]::Tls13
    } catch {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    }

    $cert2 = $null
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($TargetHost, $Port)

        $callback = [System.Net.Security.RemoteCertificateValidationCallback]{ param($s,$c,$ch,$e) return $true }
        $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, $callback)
        $sslStream.AuthenticateAsClient($TargetHost)

        $cert = $sslStream.RemoteCertificate
        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)

        $certBytes = $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($certPath, $certBytes)

        $sslStream.Close()
        $tcpClient.Close()

        return $cert2
    }
    finally {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    }
}

function Print-CertInfo {
    param($Cert2)
    Write-Host ""
    Write-Host "[2/3] Certificate Info:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------"
    Write-Host "Subject:     $($Cert2.Subject)"
    Write-Host "Issuer:      $($Cert2.Issuer)"
    Write-Host "Valid From:  $($Cert2.NotBefore)"
    Write-Host "Valid To:    $($Cert2.NotAfter)"
    Write-Host "Thumbprint:  $($Cert2.Thumbprint)"
    Write-Host "-------------------------------------------"
    Write-Host ""
}

function Install-ToTrustedRoot {
    param($Cert2)

    Write-Host "[3/3] Installing certificate to trusted store..." -ForegroundColor Yellow

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    try {
        $existing = $store.Certificates | Where-Object { $_.Thumbprint -eq $Cert2.Thumbprint }
        if ($existing.Count -gt 0) {
            Write-Host "Certificate already exists in Trusted Root store (same thumbprint)." -ForegroundColor DarkGreen
        } else {
            $store.Add($Cert2)
            Write-Host ""
            Write-Host "SUCCESS! Certificate added to Trusted Root CA!" -ForegroundColor Green
        }
    }
    finally {
        $store.Close()
    }
}

Write-Host "[1/3] Downloading certificate..." -ForegroundColor Yellow

$cert2 = $null
try {
    switch ($Mode) {
        "http" {
            $cert2 = Get-CertFromHttp -TargetHost $targetHost
            Write-Host "Certificate saved to: $certPath" -ForegroundColor Green
        }
        "tls" {
            $cert2 = Get-CertFromTls -TargetHost $targetHost -Port $port
            Write-Host "Certificate saved to: $certPath" -ForegroundColor Green
        }
        "auto" {
            try {
                $cert2 = Get-CertFromHttp -TargetHost $targetHost
                Write-Host "✅ Got certificate via HTTP" -ForegroundColor Green
                Write-Host "Certificate saved to: $certPath" -ForegroundColor Green
            } catch {
                Write-Host "HTTP download failed, falling back to TLS... ($($_.Exception.Message))" -ForegroundColor DarkYellow
                $cert2 = Get-CertFromTls -TargetHost $targetHost -Port $port
                Write-Host "✅ Got certificate via TLS" -ForegroundColor Green
                Write-Host "Certificate saved to: $certPath" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "Error: Cannot download certificate - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not $cert2) {
    Write-Host "Error: Certificate object is empty" -ForegroundColor Red
    exit 1
}

Print-CertInfo -Cert2 $cert2
Install-ToTrustedRoot -Cert2 $cert2

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "Note: Restart browser/app to apply changes" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan