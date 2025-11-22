# Code Formatting
# ---------------

# Format all GDScript files in the project
[group('formatting')]
format:
    uv run --with gdtoolkit gdformat .

# Check formatting without modifying files (useful for CI/CD)
[group('formatting')]
format-check:
    uv run --with gdtoolkit gdformat . --check

# Format a specific file or directory
[group('formatting')]
format-path path:
    uv run --with gdtoolkit gdformat {{path}}

# Format only changed files (git diff)
[group('formatting')]
format-changed:
    git diff --name-only --diff-filter=ACMR "*.gd" | xargs -r uv run --with gdtoolkit gdformat

# Format files in staging area
[group('formatting')]
format-staged:
    git diff --staged --name-only --diff-filter=ACMR "*.gd" | xargs -r uv run --with gdtoolkit gdformat
