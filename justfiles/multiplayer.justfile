# Multiplayer & Signaling Server Recipes

# Start the WebRTC signaling server for web multiplayer
[group('multiplayer')]
signaling-server:
    @Write-Host "Starting WebRTC signaling server on http://localhost:3000" -ForegroundColor Cyan
    @Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    uv run signaling-server/server.py

# Start signaling server on a custom port
[group('multiplayer')]
signaling-server-port port:
    @Write-Host "Starting WebRTC signaling server on http://localhost:{{port}}" -ForegroundColor Cyan
    @Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    uv run signaling-server/server.py --port {{port}}

# Start both signaling server and web server for full multiplayer testing
[group('multiplayer')]
test-multiplayer:
    @Write-Host "For multiplayer testing, run these commands in separate terminals:" -ForegroundColor Cyan
    @Write-Host ""
    @Write-Host "  Terminal 1: just signaling-server" -ForegroundColor Yellow
    @Write-Host "  Terminal 2: just test-web-local" -ForegroundColor Yellow
    @Write-Host ""
    @Write-Host "Then open multiple browser tabs to http://localhost:8000" -ForegroundColor Green
