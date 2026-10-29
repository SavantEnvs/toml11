#!/usr/bin/env bash
#
# mayhem/test.sh — RUN toml11's own doctest suite (built by mayhem/build.sh) plus a known-answer probe.
# exit 0 = pass. Each test binary is run directly and its doctest summary parsed (ctest only sees
# exit codes); the probe's output is compared against fixed expected values.
#
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


TESTDIR="$SRC/build/tests/tests"
KAT="$SRC/build/kat"
[ -x "$KAT" ] && [ -d "$TESTDIR" ] || { echo "test.sh: build/ artifacts missing — run mayhem/build.sh first" >&2; exit 1; }

passed=0; failed=0; skipped=0

# 1) Unit tests: one doctest binary per file; count its test cases.
shopt -s nullglob
bins=("$TESTDIR"/test_*)
[ "${#bins[@]}" -gt 0 ] || { echo "test.sh: no test binaries in $TESTDIR" >&2; exit 1; }
for b in "${bins[@]}"; do
  [ -f "$b" ] && [ -x "$b" ] || continue
  out="$(cd "$TESTDIR" && "$b" 2>&1)"; rc=$?
  line="$(printf '%s\n' "$out" | grep -E '^\[doctest\] test cases:' | tail -n1)"
  if [ -z "$line" ]; then
    echo "FAIL $(basename "$b"): no doctest summary (rc=$rc)"; failed=$((failed + 1)); continue
  fi
  p="$(printf '%s' "$line" | sed -E 's/.*\| *([0-9]+) passed.*/\1/')"
  f="$(printf '%s' "$line" | sed -E 's/.*\| *([0-9]+) failed.*/\1/')"
  s="$(printf '%s' "$line" | sed -E 's/.*\| *([0-9]+) skipped.*/\1/')"
  if [ "$rc" -ne 0 ] && [ "$f" -eq 0 ]; then f=1; fi
  [ "$f" -gt 0 ] && printf '%s\n' "$out" | tail -n 30
  passed=$((passed + p)); failed=$((failed + f)); skipped=$((skipped + s))
done

# 2) Known-answer probe: parse a fixed document, compare every printed value.
expected='title=toml11
count=31
ratio=25
ok=true
when=1979-05-27T07:32:00Z
list_sum=6
host=localhost
ports=8000,8001
fruit=apple,banana
bad_is_err=1
a = 1
b = "x"'
actual="$("$KAT" 2>&1)"
while IFS= read -r want; do
  if printf '%s\n' "$actual" | grep -qxF -- "$want"; then
    passed=$((passed + 1))
  else
    echo "FAIL kat: expected line '$want'"; failed=$((failed + 1))
  fi
done <<< "$expected"

emit_ctrf "doctest+kat" "$passed" "$failed" "$skipped"
