#!/usr/bin/env bash
# run_selfcheck.sh - prove the scanner still catches the deliberate leaks in
# examples/fixtures/ and still ignores documented placeholders.
#
# Usage:
#     bash examples/run_selfcheck.sh
#     PYTHON=python3 bash examples/run_selfcheck.sh
#
# Exit code 0 = every expectation held; 1 = at least one failed.
#
# Note on exit codes: the result of a command is captured into a variable and
# $? is read immediately afterwards. Piping into `head` and reading $? would
# report the exit code of `head`, which is how smoke tests silently "pass".

set -u

ROOT_MSYS="$(cd "$(dirname "$0")/.." && pwd)"
# Native tools (python.exe on Windows) cannot open an MSYS-style path such as
# /e/repo, so convert to a drive path when the shell offers one (git-bash
# supports `pwd -W`). Elsewhere this is a no-op.
NATIVE_ROOT="$(cd "$ROOT_MSYS" && pwd -W 2>/dev/null || true)"
ROOT="${NATIVE_ROOT:-$ROOT_MSYS}"
SCANNER="$ROOT/scripts/check_secrets.py"
PYTHON_BIN="${PYTHON:-python}"
FAILURES=0

# Paths are printed relative to the repository so that this output is portable
# and safe to paste: it never carries the machine's directory layout.
echo "scanner     : ./scripts/check_secrets.py"
echo "interpreter : $PYTHON_BIN"
echo

# --- 1. the deliberate-leak fixture must be reported -------------------------
echo "== self-check 1/3: the deliberate-leak fixture must be reported =="
LEAK_OUT="$("$PYTHON_BIN" "$SCANNER" "$ROOT/examples/fixtures/leaky_sample.env" 2>&1)"
LEAK_RC=$?
echo "$LEAK_OUT"
echo "exit code: $LEAK_RC"
if [ "$LEAK_RC" -ne 1 ]; then
    echo "FAIL: expected exit code 1 from the leaky fixture"
    FAILURES=$((FAILURES + 1))
else
    echo "PASS: the leaky fixture was reported"
fi

EXPECTED_CATEGORIES="cloud-access-key credential-assignment github-token \
email-address private-ip mac-address absolute-path private-key-block jwt"
for category in $EXPECTED_CATEGORIES; do
    if printf '%s\n' "$LEAK_OUT" | grep -q "\[$category\]"; then
        echo "  caught: $category"
    else
        echo "  MISSING: $category"
        FAILURES=$((FAILURES + 1))
    fi
done
echo

# --- 2. the allowed fixture must stay clean ----------------------------------
echo "== self-check 2/3: documented placeholders must stay clean =="
ALLOWED_OUT="$("$PYTHON_BIN" "$SCANNER" "$ROOT/examples/fixtures/allowed_sample.md" 2>&1)"
ALLOWED_RC=$?
echo "$ALLOWED_OUT"
echo "exit code: $ALLOWED_RC"
if [ "$ALLOWED_RC" -ne 0 ]; then
    echo "FAIL: the allow-list regressed"
    FAILURES=$((FAILURES + 1))
else
    echo "PASS: documented placeholders are ignored"
fi
echo

# --- 3. the repository must pass its own gate --------------------------------
echo "== self-check 3/3: the repository must pass its own gate =="
echo "   (examples/fixtures is excluded: it is a deliberate canary)"
REPO_OUT="$("$PYTHON_BIN" "$SCANNER" "$ROOT" --exclude-path examples/fixtures 2>&1)"
REPO_RC=$?
echo "$REPO_OUT"
echo "exit code: $REPO_RC"
if [ "$REPO_RC" -ne 0 ]; then
    echo "FAIL: the repository does not pass its own gate"
    FAILURES=$((FAILURES + 1))
else
    echo "PASS: the repository is clean"
fi
echo

if [ "$FAILURES" -eq 0 ]; then
    echo "SELF-CHECK: PASS"
    exit 0
fi
echo "SELF-CHECK: FAIL ($FAILURES expectation(s) failed)"
exit 1
