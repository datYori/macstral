#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

fail=0
check() { # check <ram_gb> <expected tier>
  local got; got=$(recommend_ctx "$1")
  if [ "$got" = "$2" ]; then
    printf 'ok   recommend_ctx %s -> %s\n' "$1" "$got"
  else
    printf 'FAIL recommend_ctx %s -> got [%s] want [%s]\n' "$1" "$got" "$2"; fail=1
  fi
}

check 64 "comfortable"
check 32 "comfortable"
check 24 "comfortable"
check 23 "tight"
check 16 "tight"
check 8  "refused"

exit "$fail"
