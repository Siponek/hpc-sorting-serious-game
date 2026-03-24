# Code Formatting
# ---------------

# Internal: Run gdformat with arguments
_gdformat +args:
    uv run --with gdtoolkit gdformat {{ args }}

# Internal: Run gdlint with arguments
_gdlint +args:
    uv run --with gdtoolkit gdlint {{ args }}

# Format GDScript files (default: scenes directory, or specify custom path)
[group('formatting')]
format path="./scenes":
    just _gdformat {{ path }}

# Check formatting without modifying files (useful for CI/CD)
[group('formatting')]
format-check path="./scenes":
    just _gdformat {{ path }} --check

# Format only changed files (git diff)
[group('formatting')]
format-changed:
    @$files = @(git diff --name-only --diff-filter=ACMR -- "*.gd"); \
    if ($files.Count -gt 0) { just _gdformat $files } else { Write-Host "No changed GDScript files to format." -ForegroundColor Cyan }

# Format files in staging area
[group('formatting')]
format-staged:
    @$files = @(git diff --staged --name-only --diff-filter=ACMR -- "*.gd");\
    if ($files.Count -gt 0) { just _gdformat $files }\
    else\
    { Write-Host "No staged GDScript files to format." -ForegroundColor Cyan }

[group('linting')]
lint path="./scenes":
    just _gdlint {{ path }}
