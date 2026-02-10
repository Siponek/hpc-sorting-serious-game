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
    @echo "{{ CYAN }}Starting local web server on http://localhost:8000{{ NORMAL }}"
    @echo "{{ YELLOW }}Press Ctrl+C to stop the server{{ NORMAL }}" 
    @Set-Location exports/web-export; uv run python ../main.py

# Open exports folder in file explorer
[group('web-export')]
open-exports:
    @explorer exports/web-export
