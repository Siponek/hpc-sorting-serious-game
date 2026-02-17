# Network utilities for multiplayer setup
# Uses PowerShell shebang for multi-line readable scripts

# Get local IP address and copy to clipboard
[group('network')]
get-ip:
    #!powershell
    # Get all IPv4 addresses that are not localhost
    $ip = Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { 
            $_.IPAddress -ne '127.0.0.1' -and 
            ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') 
        } | 
        Select-Object -First 1 -ExpandProperty IPAddress

    if ($ip) {
        Set-Clipboard -Value $ip
        Write-Host "[OK] Local IP address: $ip" -ForegroundColor Green
        Write-Host "[OK] Copied to clipboard!" -ForegroundColor Cyan
        exit 0
    } else {
        Write-Host "[ERROR] Could not determine local IP address" -ForegroundColor Red
        exit 1
    }

# Get local IP with default port (3000) and copy to clipboard
[group('network')]
get-ip-with-port PORT="3000":
    #!powershell
    # Get all IPv4 addresses that are not localhost
    $ip = Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { 
            $_.IPAddress -ne '127.0.0.1' -and 
            ($_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual') 
        } | 
        Select-Object -First 1 -ExpandProperty IPAddress

    if ($ip) {
        $fullUrl = "${ip}:{{ PORT }}"
        Set-Clipboard -Value $fullUrl
        Write-Host "[OK] Signaling server URL: $fullUrl" -ForegroundColor Green
        Write-Host "[OK] Copied to clipboard!" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Share this URL with other players so they can connect to your lobby." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "[ERROR] Could not determine local IP address" -ForegroundColor Red
        exit 1
    }

# Display all network interfaces with their IP addresses
[group('network')]
list-ips:
    #!powershell
    Write-Host "Available network interfaces:" -ForegroundColor Cyan

    Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { $_.IPAddress -ne '127.0.0.1' } | 
        ForEach-Object {
            try {
                $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction Stop
                $statusColor = if ($adapter.Status -eq 'Up') { 'Green' } else { 'Gray' }
                Write-Host "  [$($adapter.Status)] $($adapter.Name): $($_.IPAddress)" -ForegroundColor $statusColor
            } catch {
                Write-Host "  [Unknown] Interface $($_.InterfaceIndex): $($_.IPAddress)" -ForegroundColor Gray
            }
        }

# Test if a port is available (useful for checking if signaling server is running)
[group('network')]
test-port PORT="3000":
    #!powershell
    $connection = Test-NetConnection -ComputerName localhost -Port {{ PORT }} `
        -InformationLevel Quiet -WarningAction SilentlyContinue

    if ($connection) {
        Write-Host "[OK] Port {{ PORT }} is OPEN (server is running)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "[ERROR] Port {{ PORT }} is CLOSED (server is not running)" -ForegroundColor Red
        Write-Host "  Run 'just signaling-server' to start the server" -ForegroundColor Yellow
        exit 1
    }
