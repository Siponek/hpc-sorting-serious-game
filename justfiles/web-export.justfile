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
    @cd exports/web-export && python -m http.server 8000

# Create a ZIP file for itch.io upload
[group('web-export')]
package-for-itch:
    @Write-Host "Creating ZIP package for itch.io..." -ForegroundColor Cyan
    @if (Test-Path exports/web-export.zip) { Remove-Item exports/web-export.zip }
    @Compress-Archive -Path exports/web-export/* -DestinationPath exports/web-export.zip
    @Write-Host "✓ Package created: exports/web-export.zip" -ForegroundColor Green
    @Write-Host "Upload this file to itch.io and mark it as 'played in browser'" -ForegroundColor Yellow

# Open itch.io in browser
[group('web-export')]
open-itch:
    @Start-Process "https://itch.io/game/new"

# Open exports folder in file explorer
[group('web-export')]
open-exports:
    @explorer exports\web-export

# Deploy to GitHub Pages (creates/updates gh-pages branch)
[group('web-export')]
deploy-github-pages:
    @Write-Host "Deploying to GitHub Pages..." -ForegroundColor Cyan
    @just _ensure-gh-pages-branch
    @just _copy-to-gh-pages
    @just _push-gh-pages
    @Write-Host "✓ Deployment complete!" -ForegroundColor Green
    @Write-Host "Your game will be available at:" -ForegroundColor Yellow
    @Write-Host "https://siponek.github.io/hpc-sorting-serious-game/" -ForegroundColor Green

# Prepare GitHub Pages deployment (export + setup)
[group('web-export')]
prepare-github-pages: export-web
    @Write-Host "Preparing files for GitHub Pages..." -ForegroundColor Cyan
    @just _ensure-gh-pages-branch
    @just _copy-to-gh-pages
    @Write-Host "✓ Files prepared! Review changes with:" -ForegroundColor Green
    @Write-Host "  git checkout gh-pages" -ForegroundColor Yellow
    @Write-Host "  git status" -ForegroundColor Yellow
    @Write-Host "Then deploy with: just deploy-github-pages" -ForegroundColor Yellow

# Internal: Ensure gh-pages branch exists
[private]
_ensure-gh-pages-branch:
    @$branch = git branch --list gh-pages
    @if (-not $branch) { Write-Host "Creating gh-pages branch..." -ForegroundColor Cyan; git checkout --orphan gh-pages; git rm -rf .; git commit --allow-empty -m "Initialize gh-pages"; git push -u origin gh-pages; git checkout - } else { Write-Host "✓ gh-pages branch exists" -ForegroundColor Green }

# Internal: Copy exported files to gh-pages branch
[private]
_copy-to-gh-pages:
    @$currentBranch = git branch --show-current
    @git checkout gh-pages
    @Remove-Item * -Recurse -Force -Exclude .git
    @Copy-Item exports/web-export/* . -Recurse -Force
    @Rename-Item web-export.html index.html -Force
    @git add .
    @git commit -m "Deploy web export $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ErrorAction SilentlyContinue
    @git checkout $currentBranch

# Internal: Push gh-pages branch
[private]
_push-gh-pages:
    @git push origin gh-pages
    @Write-Host "Pushed to gh-pages branch" -ForegroundColor Green
