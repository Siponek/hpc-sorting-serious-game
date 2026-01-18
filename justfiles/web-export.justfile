# Web Export & Deployment Recipes

# Export game for web using Godot
[group('web-export')]
export-web:
    @Write-Host "Exporting game for web..." -ForegroundColor Cyan
    godot --headless --export-release "Web" exports/web-export/index.html
    @Write-Host "✓ Web export complete!" -ForegroundColor Green
    @Write-Host "Output: exports/web-export/" -ForegroundColor Yellow

# Start local web server to test the game (requires Python)
[group('web-export')]
test-web-local:
    @Write-Host "Starting local web server on http://localhost:8000" -ForegroundColor Cyan
    @Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    @Set-Location exports/web-export; python -m http.server 8000

# Open exports folder in file explorer
[group('web-export')]
open-exports:
    @explorer exports\web-export
