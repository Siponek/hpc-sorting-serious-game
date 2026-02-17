# Web Export & Deployment Recipes
# Path to Godot executable

GODOT := "C:/Users/szink/Desktop/Godot Engine/4.5.1/Godot_v4.5.1-stable_win64_console.exe"

# Export game for web using Godot
[group('web-export')]
export-web:
    @echo "{{ CYAN }}Exporting game for web... {{ NORMAL }}"
    & "{{ GODOT }}" --headless --export-release "Web" exports/web-export/index.html
    @echo "{{ GREEN }}✓ Web export complete! {{ NORMAL }}"
    @echo "{{ YELLOW }}Output: exports/web-export/{{ NORMAL }}"

# Start local web server to test the game (requires Python)
[group('web-export')]
test-web-local:
    #!powershell
    Write-Host "Starting HTTPS web server on port 8000 (LAN enabled)" -ForegroundColor Cyan
    Write-Host "Open from other devices: https://<HOST_LAN_IP>:8000" -ForegroundColor Yellow
    Write-Host "Default cert paths: exports/certs/lan-cert.pem + exports/certs/lan-key.pem" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow

    if (!(Test-Path exports/certs/lan-cert.pem) -or !(Test-Path exports/certs/lan-key.pem)) {
        Write-Host "[ERROR] Missing TLS cert files. Run: just setup-lan-https" -ForegroundColor Red
        exit 1
    }

    $listeners = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
    if ($listeners) {
        Write-Host "[ERROR] Port 8000 is already in use. Stop the process first." -ForegroundColor Red
        foreach ($entry in $listeners) {
            $pid = $entry.OwningProcess
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host ("  PID {0} - {1}" -f $pid, $proc.CommandLine) -ForegroundColor Yellow
            } else {
                Write-Host ("  PID {0}" -f $pid) -ForegroundColor Yellow
            }
        }
        exit 1
    }

    Set-Location exports/web-export
    uv run python ../main.py --bind 0.0.0.0 --port 8000 --https

# Install mkcert and local CA (one-time host setup)
[group('web-export')]
install-mkcert:
    #!powershell
    if (!(Get-Command mkcert -ErrorAction SilentlyContinue)) {
        Write-Host "mkcert not found. Installing via Chocolatey..." -ForegroundColor Yellow
        choco install mkcert -y
    } else {
        Write-Host "mkcert already installed." -ForegroundColor Green
    }
    mkcert -install
    Write-Host "[OK] mkcert local CA installed on this host." -ForegroundColor Green

# Generate LAN certificate files used by test-web-local
[group('web-export')]
generate-lan-cert HOST_IP="":
    #!powershell
    if (!(Get-Command mkcert -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] mkcert is not installed. Run: just install-mkcert" -ForegroundColor Red
        exit 1
    }

    $ip = "{{ HOST_IP }}"
    if ([string]::IsNullOrWhiteSpace($ip)) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.IPAddress -ne '127.0.0.1' -and
                ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
            } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Host "[ERROR] Could not detect LAN IP. Pass it manually: just generate-lan-cert 192.168.1.14" -ForegroundColor Red
        exit 1
    }

    New-Item -ItemType Directory -Force -Path exports/certs | Out-Null
    mkcert -cert-file exports/certs/lan-cert.pem -key-file exports/certs/lan-key.pem localhost 127.0.0.1 $ip
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] mkcert failed. Certificates were not generated." -ForegroundColor Red
        exit 1
    }

    if (!(Test-Path exports/certs/lan-cert.pem) -or !(Test-Path exports/certs/lan-key.pem)) {
        Write-Host "[ERROR] mkcert reported success but cert files are missing in exports/certs." -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] LAN cert generated for IP: $ip" -ForegroundColor Green
    Write-Host "[OK] Cert: exports/certs/lan-cert.pem" -ForegroundColor Green
    Write-Host "[OK] Key:  exports/certs/lan-key.pem" -ForegroundColor Green
    Write-Host "" 
    Write-Host "Open on clients: https://${ip}:8000" -ForegroundColor Cyan

# One-command host setup for LAN HTTPS serving
[group('web-export')]
setup-lan-https HOST_IP="":
    #!powershell
    $ip = "{{ HOST_IP }}"
    if ([string]::IsNullOrWhiteSpace($ip)) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.IPAddress -ne '127.0.0.1' -and
                ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual')
            } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    if ([string]::IsNullOrWhiteSpace($ip)) {
        Write-Host "[ERROR] Could not detect LAN IP. Pass it manually: just setup-lan-https 192.168.1.14" -ForegroundColor Red
        exit 1
    }

    just install-mkcert
    just generate-lan-cert $ip
    Write-Host "[OK] LAN HTTPS setup complete for $ip" -ForegroundColor Green
    Write-Host "Next: just test-web-local" -ForegroundColor Cyan

# Open exports folder in file explorer
[group('web-export')]
open-exports:
    @explorer exports/web-export
