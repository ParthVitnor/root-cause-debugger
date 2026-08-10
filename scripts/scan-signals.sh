#!/usr/bin/env bash
# scan-signals.sh
#
# Automates the "Quick grep-able signals" table from
# references/code-quality-and-security-pass.md for stage 5 (Harden and
# sweep) of the root-cause-debugger workflow: a fast first pass over code
# you're already in, not a substitute for the judgment in that checklist.
#
# IMPORTANT: a hit here is a signal worth a closer look, not proof of a
# problem — grep has no idea about context. Read the match before deciding
# it's real. Absence of hits is not proof of absence either: two categories
# from the table are deliberately NOT included here because a grep pattern
# precise enough to be useful doesn't exist for them (see "Not covered"
# below) — that part of the sweep still has to be done by reading the code.
#
# Usage:
#   ./scan-signals.sh [--fail-on-hit] [path-or-file ...]
#
# With no path given:
#   - inside a git repo with changes: scans files changed in the working
#     tree and staged for commit — i.e. the code you just touched, which is
#     what stage 5 is actually about
#   - otherwise: scans the current directory recursively
#
# With paths given: scans exactly those files/directories instead.
#
# --fail-on-hit: exit 1 if anything was found (0 otherwise). Off by default
# since this is a report to read, not a gate — opt in if you want to wire
# it into a pre-commit hook or CI step.

set -uo pipefail

FAIL_ON_HIT=0
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --fail-on-hit) FAIL_ON_HIT=1 ;;
    *) TARGETS+=("$arg") ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    CHANGED=()
    while IFS= read -r line; do
      [ -n "$line" ] && CHANGED+=("$line")
    done < <( (git diff --name-only --diff-filter=ACMR; git diff --cached --name-only --diff-filter=ACMR) | sort -u)
    if [ ${#CHANGED[@]} -gt 0 ]; then
      TARGETS=("${CHANGED[@]}")
      echo "No path given — scanning changed files (working tree + staged): ${#TARGETS[@]} file(s)."
    else
      TARGETS=(".")
      echo "No path given and no changes detected via git diff — scanning current directory instead."
    fi
  else
    TARGETS=(".")
    echo "No path given and not inside a git repository — scanning current directory instead."
  fi
fi

# Drop targets that don't exist (e.g. a changed file that was deleted).
EXISTING=()
for t in "${TARGETS[@]}"; do
  [ -e "$t" ] && EXISTING+=("$t")
done

if [ ${#EXISTING[@]} -eq 0 ]; then
  echo "Nothing to scan." >&2
  exit 0
fi
TARGETS=("${EXISTING[@]}")

EXCLUDE_DIRS=(.git node_modules vendor venv .venv env __pycache__ dist build target .next .nuxt coverage .tox bower_components .idea .vscode)
GREP_EXCLUDES=()
for d in "${EXCLUDE_DIRS[@]}"; do
  GREP_EXCLUDES+=(--exclude-dir="$d")
done

hr() { printf '%s\n' "------------------------------------------------------------"; }

TOTAL_HITS=0
MAX_SHOWN=15

# scan LABEL PATTERN NOTE
# Greps TARGETS for an extended-regex PATTERN, prints up to MAX_SHOWN hits
# under LABEL with NOTE as context, and adds to TOTAL_HITS.
scan() {
  local label="$1" pattern="$2" note="$3"
  local matches count shown

  matches=$(grep -rnIEi "${GREP_EXCLUDES[@]}" "$pattern" -- "${TARGETS[@]}" 2>/dev/null || true)

  if [ -z "$matches" ]; then
    echo "-- $label: none found"
    return
  fi

  count=$(printf '%s\n' "$matches" | grep -c '')
  TOTAL_HITS=$((TOTAL_HITS + count))

  echo "-- $label: $count hit(s) — $note"
  shown=$(printf '%s\n' "$matches" | head -n "$MAX_SHOWN")
  echo "     ${shown//$'\n'/$'\n     '}"
  if [ "$count" -gt "$MAX_SHOWN" ]; then
    echo "     ... $((count - MAX_SHOWN)) more not shown"
  fi
  echo
}

echo "Scanning ${#TARGETS[@]} target(s) for quick grep-able signals from code-quality-and-security-pass.md"
hr

scan "Unsafe dynamic execution" \
  '(^|[^A-Za-z0-9_.])(eval|exec)\(|new[[:space:]]+Function\(' \
  "eval(/exec(/new Function() — fine if the input is a fixed literal, worth a look if any part of it is built from a variable"

scan "Command injection risk" \
  'os\.system\(|shell[[:space:]]*=[[:space:]]*True|Runtime\.getRuntime\(\)\.exec\(' \
  "os.system(, subprocess shell=True, Runtime.exec( — check whether the command includes unsanitized input"

scan "Insecure deserialization" \
  'pickle\.loads?\(|yaml\.load\(|unserialize\(' \
  "safe if yaml.load specifies a safe loader (e.g. Loader=yaml.SafeLoader) — check the call, don't just count the hit"

scan "Hardcoded secret" \
  '(password|passwd|pwd|api[_-]?key|secret|token|credential)[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{3,}["'"'"']' \
  "a literal string assigned to something secret-shaped — ignore if it's a placeholder/example/test fixture, confirm if not"

scan "Weak hashing" \
  '\b(md5|sha1)\(' \
  "fine for non-security checksums (cache keys, ETags); worth a look only if used for password/credential hashing"

scan "Predictable secret generation" \
  'Math\.random\(\)' \
  "fine for non-security randomness (jitter, sampling); worth a look only if the result becomes a token, session ID, or secret"

hr
echo "Not covered by this script (grep is too imprecise to be useful here — do these by reading the code):"
echo "  - SQL/NoSQL injection from string-built queries: any regex either misses real cases or drowns you in"
echo "    matches on ordinary string concatenation. Look at how each query is actually built instead."
echo "  - Backtick/\$() shell-out in languages where backticks are also ordinary syntax (e.g. JS/TS template"
echo "    literals): grepping backticks there is nearly all noise. Check explicit shell-out calls by name"
echo "    instead (child_process.exec, Ruby's \`cmd\`, PHP's \`cmd\`, etc.)."
hr

echo "Total signals: $TOTAL_HITS across the categories above (0 in a category just means grep found nothing — not that the category is clean)."

if [ "$FAIL_ON_HIT" -eq 1 ] && [ "$TOTAL_HITS" -gt 0 ]; then
  exit 1
fi
exit 0
