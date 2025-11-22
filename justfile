# This justfile works with windows
set windows-powershell := true

# Import formatter recipes
import 'justfiles/formatter.justfile'

default:
    @just --list

# Dependencies & Submodules
# -------------------------

# Update GD-Sync submodule
[group('dependencies')]
update-gd-sync:
    git submodule update --init --recursive

# Link the submodule to addons folder for Godot (Windows). Will reimport stuff in engine when editor is opened, so be patient
[group('dependencies')]
update-gd-sync-windows: update-gd-sync delete-gd-sync-link
    @New-Item -ItemType SymbolicLink -Path addons/GD-Sync -Target git-submodules/GD-Sync/addons/GD-Sync

# Verify GD-Sync symbolic link is correctly set up
[group('dependencies')]
verify-gd-sync-link:
    @$item = Get-Item addons/GD-Sync; if ($item.Attributes -match "ReparsePoint") { Write-Host "✓ GD-Sync is correctly linked to: $($item.Target)" -ForegroundColor Green } else { Write-Host "✗ GD-Sync is not a symbolic link" -ForegroundColor Red }

# Delete GD-Sync symbolic link
[group('dependencies')]
delete-gd-sync-link:
    @if (Test-Path addons/GD-Sync) { Remove-Item addons/GD-Sync -Recurse -Force; Write-Host "✓ GD-Sync symbolic link deleted" -ForegroundColor Green } else { Write-Host "✗ GD-Sync symbolic link does not exist" -ForegroundColor Red }