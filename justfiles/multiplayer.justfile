# Multiplayer & Signaling Server Recipes

# Start the WebRTC signaling server for web multiplayer
[group('multiplayer')]
signaling-server:
    @Write-Host "{{ CYAN }}Starting WebRTC signaling server on http://localhost:3000{{ NORMAL }}"
    @Write-Host "{{ YELLOW }}Press Ctrl+C to stop the server{{ NORMAL }}"
    uv run signaling-server/server.py

# Start signaling server on a custom port
[group('multiplayer')]
signaling-server-port port:
    @Write-Host "{{ CYAN }}Starting WebRTC signaling server on http://localhost:{{ port }}{{ NORMAL }}"
    @Write-Host "{{ YELLOW }}Press Ctrl+C to stop the server{{ NORMAL }}"
    uv run signaling-server/server.py --port {{ port }}

# Start both signaling server and web server for full multiplayer testing
[group('multiplayer')]
test-multiplayer:
    @Write-Host "{{ CYAN }}For multiplayer testing, run these commands in separate terminals:{{ NORMAL }}"
    @Write-Host ""
    @Write-Host "{{ YELLOW }}  Terminal 1: just signaling-server{{ NORMAL }}" 
    @Write-Host "{{ YELLOW }}  Terminal 2: just test-web-local{{ NORMAL }}"
    @Write-Host ""
    @Write-Host "{{ GREEN }}Then open multiple browser tabs to http://localhost:8000 {{ NORMAL }}"
