# Thesis Compilation
# ------------------

# Thesis directory
thesis_dir := "thesis"
diagrams_dir := thesis_dir / "figures/diagrams"

# Compile main thesis document
[group('thesis')]
compile-thesis:
    @echo "Compiling main thesis document..."
    @cd {{thesis_dir}}; pdflatex main.tex
    @cd {{thesis_dir}}; biber main
    @cd {{thesis_dir}}; pdflatex main.tex
    @cd {{thesis_dir}}; pdflatex main.tex
    @echo "✓ Thesis compilation complete! Output: thesis/main.pdf"

# Compile all PlantUML diagrams to PDF
[group('thesis')]
compile-diagrams:
    @echo "Compiling PlantUML diagrams..."
    cd {{diagrams_dir}} && plantuml -tpdf *.puml
    @echo "✓ All PlantUML diagrams compiled!"

# Compile PlantUML diagrams to PNG
[group('thesis')]
compile-diagrams-png:
    @echo "Compiling PlantUML diagrams to PNG..."
    cd {{diagrams_dir}} && plantuml -tpng *.puml
    @echo "✓ All PlantUML diagrams compiled to PNG!"

# Compile a specific PlantUML diagram (usage: just compile-diagram http-sse-architecture)
[group('thesis')]
compile-diagram name:
    @echo "Compiling diagram: {{name}}.puml..."
    cd {{diagrams_dir}} && plantuml -tpdf {{name}}.puml
    @echo "✓ Diagram compiled: {{diagrams_dir}}/{{name}}.pdf"

# Clean thesis auxiliary files
[group('thesis')]
clean-thesis:
    @echo "Cleaning thesis auxiliary files..."
    @if (Test-Path {{thesis_dir}}/main.aux) { Remove-Item {{thesis_dir}}/main.aux }
    @if (Test-Path {{thesis_dir}}/main.bbl) { Remove-Item {{thesis_dir}}/main.bbl }
    @if (Test-Path {{thesis_dir}}/main.bcf) { Remove-Item {{thesis_dir}}/main.bcf }
    @if (Test-Path {{thesis_dir}}/main.blg) { Remove-Item {{thesis_dir}}/main.blg }
    @if (Test-Path {{thesis_dir}}/main.fdb_latexmk) { Remove-Item {{thesis_dir}}/main.fdb_latexmk }
    @if (Test-Path {{thesis_dir}}/main.fls) { Remove-Item {{thesis_dir}}/main.fls }
    @if (Test-Path {{thesis_dir}}/main.log) { Remove-Item {{thesis_dir}}/main.log }
    @if (Test-Path {{thesis_dir}}/main.lof) { Remove-Item {{thesis_dir}}/main.lof }
    @if (Test-Path {{thesis_dir}}/main.lot) { Remove-Item {{thesis_dir}}/main.lot }
    @if (Test-Path {{thesis_dir}}/main.lol) { Remove-Item {{thesis_dir}}/main.lol }
    @if (Test-Path {{thesis_dir}}/main.out) { Remove-Item {{thesis_dir}}/main.out }
    @if (Test-Path {{thesis_dir}}/main.run.xml) { Remove-Item {{thesis_dir}}/main.run.xml }
    @if (Test-Path {{thesis_dir}}/main.toc) { Remove-Item {{thesis_dir}}/main.toc }
    @if (Test-Path {{thesis_dir}}/indent.log) { Remove-Item {{thesis_dir}}/indent.log }
    @echo "✓ Thesis auxiliary files cleaned!"

# Clean diagram auxiliary files
[group('thesis')]
clean-diagrams:
    @echo "Cleaning diagram auxiliary files..."
    @Get-ChildItem -Path {{diagrams_dir}} -Include *.aux,*.log -Recurse | Remove-Item -Force
    @echo "✓ Diagram auxiliary files cleaned!"

# Clean all thesis and diagram auxiliary files
[group('thesis')]
clean-all: clean-thesis clean-diagrams
    @echo "✓ All auxiliary files cleaned!"

# Full rebuild: clean and compile everything
[group('thesis')]
rebuild: clean-all compile-diagrams compile-thesis
    @echo "✓ Full thesis rebuild complete!"

# Quick compile (only once, useful for quick checks)
[group('thesis')]
quick-compile:
    @echo "Quick compiling thesis..."
    cd {{thesis_dir}} && pdflatex main.tex
    @echo "✓ Quick compilation complete! (Note: bibliography may not be updated)"

# Open the compiled thesis PDF
[group('thesis')]
open-thesis:
    @Start-Process {{thesis_dir}}/main.pdf

# View thesis compilation log
[group('thesis')]
view-log:
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log } else { Write-Host "No log file found" -ForegroundColor Red }

# Show only critical errors from the log (fatal errors that prevent PDF generation)
[group('thesis')]
errors:
    @echo "Scanning for critical LaTeX errors..."
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "^!" | ForEach-Object { Write-Host $_ -ForegroundColor Red } } else { Write-Host "No log file found. Run compile-thesis first." -ForegroundColor Yellow }
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "Runaway argument" | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "Emergency stop" | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "Fatal error" | ForEach-Object { Write-Host $_ -ForegroundColor Red } }
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "File .* not found" | ForEach-Object { Write-Host $_ -ForegroundColor Red } }

# Show warnings from the log (undefined references, citations, etc.)
[group('thesis')]
warnings:
    @echo "Scanning for LaTeX warnings..."
    @if (Test-Path {{thesis_dir}}/main.log) { Get-Content {{thesis_dir}}/main.log | Select-String -Pattern "LaTeX Warning" | ForEach-Object { Write-Host $_ -ForegroundColor Yellow } } else { Write-Host "No log file found. Run compile-thesis first." -ForegroundColor Yellow }

# Watch for changes and recompile thesis automatically
[group('thesis')]
watch:
    @echo "Starting thesis watch mode... (Ctrl+C to stop)"
    @echo "Watching for .tex file changes in {{thesis_dir}}/"
    @$lastWrite = @{}; Get-ChildItem -Path {{thesis_dir}} -Filter *.tex -Recurse | ForEach-Object { $lastWrite[$_.FullName] = $_.LastWriteTime }; while ($true) { Start-Sleep -Seconds 2; $changed = $false; Get-ChildItem -Path {{thesis_dir}} -Filter *.tex -Recurse | ForEach-Object { if (-not $lastWrite.ContainsKey($_.FullName) -or $lastWrite[$_.FullName] -lt $_.LastWriteTime) { $lastWrite[$_.FullName] = $_.LastWriteTime; $changed = $true; Write-Host "Changed: $($_.Name)" -ForegroundColor Yellow } }; if ($changed) { Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Recompiling..." -ForegroundColor Cyan; Set-Location {{thesis_dir}}; pdflatex -interaction=nonstopmode main.tex | Out-Null; if ($LASTEXITCODE -eq 0) { Write-Host "✓ Compiled successfully" -ForegroundColor Green } else { Write-Host "✗ Compilation failed - check main.log" -ForegroundColor Red }; Set-Location .. } }

# Watch with full rebuild (includes biber for bibliography updates)
[group('thesis')]
watch-full:
    @echo "Starting thesis watch mode with full rebuild... (Ctrl+C to stop)"
    @echo "Watching for .tex and .bib file changes in {{thesis_dir}}/"
    @$lastWrite = @{}; Get-ChildItem -Path {{thesis_dir}} -Include *.tex,*.bib -Recurse | ForEach-Object { $lastWrite[$_.FullName] = $_.LastWriteTime }; while ($true) { Start-Sleep -Seconds 2; $changed = $false; Get-ChildItem -Path {{thesis_dir}} -Include *.tex,*.bib -Recurse | ForEach-Object { if (-not $lastWrite.ContainsKey($_.FullName) -or $lastWrite[$_.FullName] -lt $_.LastWriteTime) { $lastWrite[$_.FullName] = $_.LastWriteTime; $changed = $true; Write-Host "Changed: $($_.Name)" -ForegroundColor Yellow } }; if ($changed) { Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Full rebuild..." -ForegroundColor Cyan; Set-Location {{thesis_dir}}; pdflatex -interaction=nonstopmode main.tex | Out-Null; biber main 2>$null; pdflatex -interaction=nonstopmode main.tex | Out-Null; pdflatex -interaction=nonstopmode main.tex | Out-Null; if ($LASTEXITCODE -eq 0) { Write-Host "✓ Full rebuild complete" -ForegroundColor Green } else { Write-Host "✗ Compilation failed - check main.log" -ForegroundColor Red }; Set-Location .. } }
