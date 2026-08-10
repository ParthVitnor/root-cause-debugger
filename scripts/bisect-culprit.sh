#!/usr/bin/env bash
# bisect-culprit.sh
#
# Generic "find the first bad one" helper for stage 2 (Localize) of the
# root-cause-debugger workflow. Two modes:
#
#   Commit mode — wraps `git bisect` to find the commit that introduced a
#   failure, given a known-good and known-bad commit and a check command
#   that exits 0 on good / non-zero on bad.
#
#     ./bisect-culprit.sh --commits <good-sha> <bad-sha> -- <check-command>
#
#     Example:
#       ./bisect-culprit.sh --commits v1.4.0 HEAD -- "npm test -- report.test.js"
#
#   List mode — runs a command against each item in an explicit list (test
#   files, config variants, feature flags, anything enumerable) and stops at
#   the first one where the command fails. Use {} in the command as a
#   placeholder for the current item.
#
#     ./bisect-culprit.sh --list item1 item2 item3 -- <command-with-{}>
#
#     Example:
#       ./bisect-culprit.sh --list src/*.test.js -- "npm test {}"
#
# In both modes, "fails" means the check command exits non-zero.

set -uo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  bisect-culprit.sh --commits <good-sha> <bad-sha> -- <check-command>
  bisect-culprit.sh --list <item1> [item2 ...] -- <command-with-{}>

See the top of this script for examples.
EOF
  exit 1
}

[ $# -ge 1 ] || usage

MODE="$1"; shift

case "$MODE" in
  --commits)
    [ $# -ge 3 ] || usage
    GOOD_SHA="$1"; BAD_SHA="$2"; shift 2
    [ "$1" = "--" ] || usage
    shift
    CHECK_CMD="$*"
    [ -n "$CHECK_CMD" ] || usage

    if ! git rev-parse --git-dir > /dev/null 2>&1; then
      echo "Not inside a git repository." >&2
      exit 1
    fi

    echo "Bisecting commits between known-good '$GOOD_SHA' and known-bad '$BAD_SHA'"
    echo "Check command: $CHECK_CMD"
    echo

    git bisect start "$BAD_SHA" "$GOOD_SHA" > /dev/null
    # `git bisect run` invokes the command at each candidate commit and
    # interprets its exit code: 0 = good, 1-124/126-127 = bad, 125 = skip.
    git bisect run bash -c "$CHECK_CMD"
    RESULT=$?

    echo
    echo "First bad commit (if found above):"
    git bisect log | grep -m1 '^# first bad commit' || echo "(see git bisect output above for the result)"

    git bisect reset > /dev/null
    exit $RESULT
    ;;

  --list)
    ITEMS=()
    while [ $# -gt 0 ] && [ "$1" != "--" ]; do
      ITEMS+=("$1")
      shift
    done
    [ "${1:-}" = "--" ] || usage
    shift
    CMD_TEMPLATE="$*"
    [ -n "$CMD_TEMPLATE" ] || usage
    [ ${#ITEMS[@]} -gt 0 ] || { echo "No items given to --list." >&2; usage; }

    TOTAL=${#ITEMS[@]}
    echo "Checking $TOTAL candidate(s). Command template: $CMD_TEMPLATE"
    echo

    COUNT=0
    for ITEM in "${ITEMS[@]}"; do
      COUNT=$((COUNT + 1))
      # Substitute {} with the current item; if no {} present, item is appended.
      if [[ "$CMD_TEMPLATE" == *'{}'* ]]; then
        RUN_CMD="${CMD_TEMPLATE//\{\}/$ITEM}"
      else
        RUN_CMD="$CMD_TEMPLATE $ITEM"
      fi

      printf '[%d/%d] %s ... ' "$COUNT" "$TOTAL" "$ITEM"
      if bash -c "$RUN_CMD" > /tmp/bisect-culprit.log 2>&1; then
        echo "ok"
      else
        echo "FAIL"
        echo
        echo "First failing candidate: $ITEM"
        echo "Command:                 $RUN_CMD"
        echo "Output (last 20 lines):"
        tail -n 20 /tmp/bisect-culprit.log
        exit 1
      fi
    done

    echo
    echo "No failures found across $TOTAL candidate(s)."
    exit 0
    ;;

  *)
    usage
    ;;
esac
