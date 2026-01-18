# Code Formatting
# ---------------

# Internal: Run gdformat with arguments
_gdformat +args:
    uv run --with gdtoolkit gdformat {{args}}

# Internal: Run gdlint with arguments
_gdlint +args:
    uv run --with gdtoolkit gdlint {{args}}


# Format GDScript files (default: scenes directory, or specify custom path)
[group('formatting')]
format path="./scenes":
    just _gdformat {{path}}

# Check formatting without modifying files (useful for CI/CD)
[group('formatting')]
format-check path="./scenes":
    just _gdformat {{path}} --check

# Format only changed files (git diff)
[group('formatting')]
format-changed:
    git diff --name-only --diff-filter=ACMR "*.gd" | xargs -r just _gdformat

# Format files in staging area
[group('formatting')]
format-staged:
    git diff --staged --name-only --diff-filter=ACMR "*.gd" | xargs -r just _gdformat

[group('linting')]
lint path="./scenes":
    just _gdlint {{path}}