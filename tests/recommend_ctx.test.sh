#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

fail=0
check() { # check <ram_gb> <expected "ctx tier">
  local got; got=$(recommend_ctx "$1")
  if [ "$got" = "$2" ]; then
    printf 'ok   recommend_ctx %s -> %s\n' "$1" "$got"
  else
    printf 'FAIL recommend_ctx %s -> got [%s] want [%s]\n' "$1" "$got" "$2"; fail=1
  fi
}

check 64 "32000 comfortable"
check 32 "32000 comfortable"
check 31 "16000 ok-tight"
check 24 "16000 ok-tight"
check 23 "8000 tight"
check 16 "8000 tight"
check 8  "0 refused"

exit "$fail"
