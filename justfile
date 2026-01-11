# This justfile works with windows

set windows-powershell := true

# Import formatter recipes

import 'justfiles/formatter.justfile'

# Import thesis compilation recipes

import 'justfiles/thesis.justfile'

# Import web export recipes

import 'justfiles/web-export.justfile'

# Import multiplayer recipes

import 'justfiles/multiplayer.justfile'


default:
    @just --list

# Dependencies & Submodules
# -------------------------

# Fetch and update all submodules in git-submodules directory
[group('dependencies')]
update-submodules:
    git submodule update --init --recursive --remote

# Link the submodule to addons folder for Godot (Windows). Will reimport stuff in engine when editor is opened, so be patient
[group('dependencies')]
create-gd-sync-windows: update-submodules delete-gd-sync-link
    @try { New-Item -ItemType SymbolicLink -Path addons/GD-Sync -Target git-submodules/GD-Sync/addons/GD-Sync -ErrorAction Stop; Write-Host "✓ GD-Sync symbolic link created successfully" -ForegroundColor Green } catch { Write-Host "✗ Failed to create symbolic link. Administrator rights may be required." -ForegroundColor Red; Write-Host "  Please run PowerShell as Administrator or enable Developer Mode in Windows Settings." -ForegroundColor Yellow; exit 1 }

# Verify GD-Sync symbolic link is correctly set up
[group('dependencies')]
verify-gd-sync-link:
    @$item = Get-Item addons/GD-Sync; if ($item.Attributes -match "ReparsePoint") { Write-Host "✓ GD-Sync is correctly linked to: $($item.Target)" -ForegroundColor Green } else { Write-Host "✗ GD-Sync is not a symbolic link" -ForegroundColor Red }

# Delete GD-Sync symbolic link
[group('dependencies')]
delete-gd-sync-link:
    @if (Test-Path addons/GD-Sync) { try { Remove-Item addons/GD-Sync -Recurse -Force -ErrorAction Stop; Write-Host "✓ GD-Sync symbolic link deleted" -ForegroundColor Green } catch { Write-Host "✗ Failed to delete symbolic link. Administrator rights may be required." -ForegroundColor Red; exit 1 } } else { Write-Host "ℹ GD-Sync symbolic link does not exist (skipping)" -ForegroundColor Cyan }

# Change GDSync module to forked fixed version. This will be changed once GDSync merges the change to main repo
[group('dependencies')]
change-gd-sync-fork:
    git config -f .gitmodules submodule.git-submodules/GD-Sync.url https://github.com/Siponek/GD-Sync-fork.git
    git config -f .gitmodules submodule.git-submodules/GD-Sync.branch fix/local-multiplayer-packets-types
    git submodule sync
    just update-submodules
    git add .gitmodules git-submodules/GD-Sync
