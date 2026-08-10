#!/usr/bin/env bash
# collect-evidence.sh
#
# Gathers stack-independent context for stage 1 of the root-cause-debugger
# workflow: recent history, working-tree state, and a best-effort guess at
# what language/stack this project is, so an investigation doesn't start
# from a blank page.
#
# Usage:
#   ./collect-evidence.sh [path-to-repo] [number-of-commits]
#
# Defaults to the current directory and the last 15 commits.

set -uo pipefail

REPO_DIR="${1:-.}"
COMMIT_COUNT="${2:-15}"

cd "$REPO_DIR" || { echo "Cannot access directory: $REPO_DIR" >&2; exit 1; }

hr() { printf '%s\n' "------------------------------------------------------------"; }

echo "Evidence collected from: $(pwd)"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
hr

if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
  echo "## Recent commits (last $COMMIT_COUNT)"
  git log -n "$COMMIT_COUNT" --pretty=format:'%h  %ad  %an  %s' --date=short 2>/dev/null \
    || echo "(unable to read git log)"
  echo
  hr

  echo "## Uncommitted changes (working tree vs HEAD)"
  CHANGED=$(git status --porcelain 2>/dev/null)
  if [ -n "$CHANGED" ]; then
    echo "$CHANGED"
    echo
    echo "-- diff stat --"
    git diff --stat 2>/dev/null
  else
    echo "(clean working tree)"
  fi
  echo
  hr

  echo "## Current branch / last known-good reference points"
  echo "Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
  echo "HEAD:   $(git log -1 --pretty=format:'%h %s' 2>/dev/null)"
  echo "Tip: to diff against a specific earlier point, run:"
  echo "  git diff <last-known-good-sha>..HEAD"
else
  echo "## Version control"
  echo "Not a git repository (or git is unavailable) — recent-changes detection skipped."
  echo "If this project uses a different VCS, check its log manually."
fi

hr
echo "## Detected project / language markers"

# Bash 3.2–compatible marker lookup (no associative arrays).
marker_label() {
  case "$1" in
    package.json)     echo "Node.js / JavaScript / TypeScript" ;;
    pyproject.toml)   echo "Python (Poetry/PEP 621)" ;;
    requirements.txt) echo "Python (pip)" ;;
    Pipfile)          echo "Python (pipenv)" ;;
    go.mod)           echo "Go" ;;
    Cargo.toml)       echo "Rust" ;;
    pom.xml)          echo "Java (Maven)" ;;
    build.gradle)     echo "Java/Kotlin (Gradle)" ;;
    build.gradle.kts) echo "Kotlin (Gradle)" ;;
    Gemfile)          echo "Ruby" ;;
    composer.json)    echo "PHP" ;;
    *.csproj)         echo ".NET / C#" ;;
    mix.exs)          echo "Elixir" ;;
    Package.swift)    echo "Swift" ;;
    *)                echo "unknown" ;;
  esac
}

MARKERS="package.json pyproject.toml requirements.txt Pipfile go.mod Cargo.toml pom.xml build.gradle build.gradle.kts Gemfile composer.json *.csproj mix.exs Package.swift"

FOUND_ANY=0
for marker in $MARKERS; do
  if compgen -G "$marker" > /dev/null 2>&1; then
    echo "  found: $marker  ->  $(marker_label "$marker")"
    FOUND_ANY=1
  fi
done

if [ "$FOUND_ANY" -eq 0 ]; then
  echo "  (no common project markers found in $(pwd) — check subdirectories, or this may be a monorepo)"
fi

hr
echo "## Suggested next step"
echo "Cross-reference the commits above against when the failure started."
echo "If a specific commit looks suspicious, isolate it with:"
echo "  ./bisect-culprit.sh --commits <known-good-sha> <known-bad-sha> -- '<command that exits 0 on good>'"
