#!/usr/bin/env bash
#
# mayhem/build.sh — build toml11's fuzz harnesses (sanitized, DWARF 3), their standalone
# reproducers, the KAT probe, and the project's unit tests (normal flags, built under build/,
# which upstream's .gitignore covers). Re-runnable and offline: no step fetches anything.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"
OBJ="$SRC/build/fuzz"
mkdir -p "$OBJ"

# 1) toml11 is header-only: the project is instrumented by compiling it into each harness TU.
#    Support objects: LLVM's run-once driver (as C, so its LLVMFuzzerTestOneInput ref is not
#    mangled) and the LeakSanitizer-off hook.
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$OBJ/standalone_main.o"
# shellcheck disable=SC2086
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$OBJ/lsan_off.o"

# 2) Each harness twice: libFuzzer binary and -standalone reproducer.
for h in parse_fuzzer roundtrip_fuzzer; do
  # shellcheck disable=SC2086
  $CXX -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -I"$SRC/include" \
      "$SRC/mayhem/harnesses/$h.cpp" "$OBJ/lsan_off.o" $LIB_FUZZING_ENGINE \
      -o "$SRC/$h"
  # shellcheck disable=SC2086
  $CXX -O1 $SANITIZER_FLAGS $DEBUG_FLAGS -I"$SRC/include" \
      "$SRC/mayhem/harnesses/$h.cpp" "$OBJ/standalone_main.o" "$OBJ/lsan_off.o" \
      -o "$SRC/$h-standalone"
done

# 3) Test suite with the project's NORMAL flags (no sanitizers). doctest comes from apt
#    (the tests/extlib/doctest submodule is empty in this tree).
cmake -S "$SRC" -B "$SRC/build/tests" \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
      -DTOML11_BUILD_TESTS=ON \
      -DCMAKE_CXX_FLAGS="-I/usr/include/doctest $COVERAGE_FLAGS" \
      -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS"
cmake --build "$SRC/build/tests" -j"$MAYHEM_JOBS"

# KAT probe, also normal flags.
$CXX -std=c++11 $COVERAGE_FLAGS -I"$SRC/include" "$SRC/mayhem/kat.cpp" -o "$SRC/build/kat"
