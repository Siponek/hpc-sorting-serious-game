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

# Compile all TikZ diagrams
[group('thesis')]
compile-diagrams:
    @echo "Compiling TikZ diagrams..."
    @cd {{diagrams_dir}}; pdflatex physical-to-digital-mapping.tex
    @cd {{diagrams_dir}}; pdflatex openmp-vs-mpi-modes.tex
    @cd {{diagrams_dir}}; pdflatex sequential-vs-openmp-modes.tex
    @echo "✓ All diagrams compiled successfully!"

# Compile a specific diagram (usage: just compile-diagram physical-to-digital-mapping)
[group('thesis')]
compile-diagram name:
    @echo "Compiling diagram: {{name}}.tex..."
    @cd {{diagrams_dir}}; pdflatex {{name}}.tex
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
