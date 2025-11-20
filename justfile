# This justfile works with windows
set windows-powershell := true

### Adding library submodule GD-Sync for Godot project synchronization
### Reason being that the library is contantly updated, so having it as a submodule makes it easier to update
### Than it is to have it as an addon in Godot
### Usage: just update-gd-sync-windows

default:
    @just --list

update-gd-sync:
    git submodule update --init --recursive

### Link the submodule to addons folder for godot. Will reimport stuff in engine when editor is opened, so be patient
update-gd-sync-windows: update-gd-sync delete-gd-sync-link
    @New-Item -ItemType SymbolicLink -Path addons/GD-Sync -Target git-submodules/GD-Sync/addons/GD-Sync

verify-gd-sync-link:
    @$item = Get-Item addons/GD-Sync; if ($item.Attributes -match "ReparsePoint") { Write-Host "✓ GD-Sync is correctly linked to: $($item.Target)" -ForegroundColor Green } else { Write-Host "✗ GD-Sync is not a symbolic link" -ForegroundColor Red }

delete-gd-sync-link:
    @if (Test-Path addons/GD-Sync) { Remove-Item addons/GD-Sync -Recurse -Force; Write-Host "✓ GD-Sync symbolic link deleted" -ForegroundColor Green } else { Write-Host "✗ GD-Sync symbolic link does not exist" -ForegroundColor Red }