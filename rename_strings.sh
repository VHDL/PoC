#!/usr/bin/env bash
#
# rename_strings.sh (v2) — recursively rename files AND folders, replacing
# every occurrence of OLD with NEW in their names, for one or more OLD/NEW
# pairs. Matching of OLD is CASE-INSENSITIVE; the result is written in the
# exact casing of NEW.
#
# Usage:
#   ./rename_strings.sh [-n] OLD1 NEW1 [OLD2 NEW2 ...]
#     -n, --dry-run   print what would be renamed, change nothing
#
# Example:
#   ./rename_strings.sh cache_TagUnit_Par cache_TagUnit_Parallel addw Adder_Wide
#   # also matches Cache_TagUnit_PAR, ADDW, Addw, ...
#
# Safeguard: for each pair, any entry whose name already contains NEW (in any
# casing) is skipped (the "grep -v NEW" step). This stops a partial match such
# as cache_TagUnit_Par -> cache_TagUnit_Parallel from being applied twice.
# (Because the safeguard is case-insensitive, case-only renames are a no-op.)
#
# Requires bash >= 4 (uses case-insensitive ${var//old/new}).

set -uo pipefail
shopt -s nocasematch

# Fail clearly on a bash too old for case-insensitive ${var//...} (e.g. macOS
# system bash 3.2) instead of silently skipping files.
_probe="ABC"
if [[ "${_probe//abc/X}" != "X" ]]; then
  echo "error: this bash lacks case-insensitive \${var//...}; use bash >= 4." >&2
  exit 1
fi

dry_run=0
if [[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]]; then
  dry_run=1
  shift
fi

if [[ $# -lt 2 || $(( $# % 2 )) -ne 0 ]]; then
  echo "Usage: $0 [-n] OLD1 NEW1 [OLD2 NEW2 ...]" >&2
  exit 1
fi

while [[ $# -ge 2 ]]; do
  old=$1
  new=$2
  shift 2

  if [[ -z "$old" ]]; then
    echo "skip: empty OLD string" >&2
    continue
  fi
  if [[ "$old" == "$new" ]]; then
    echo "skip: OLD == NEW ('$old')" >&2
    continue
  fi

  echo "== pair: '$old' -> '$new' (case-insensitive) =="

  # -depth processes the deepest entries first, so children are renamed
  # before their parent folder and the pending paths stay valid.
  # -iname "*$old*" matches the basename case-insensitively.
  find . -depth -not -path './.git/*' -iname "*$old*" -print0 |
  while IFS= read -r -d '' path; do
    base=$(basename "$path")

    # safeguard: skip names that already contain NEW (case-insensitive)
    case "$base" in
      *"$new"*) continue ;;
    esac

    newbase=${base//"$old"/"$new"}   # case-insensitive literal replace
    newpath="$(dirname "$path")/$newbase"

    if [[ -e "$newpath" ]]; then
      echo "skip: target already exists: $newpath" >&2
      continue
    fi

    if [[ "$dry_run" -eq 1 ]]; then
      printf 'would rename: %s -> %s\n' "$path" "$newpath"
    else
      mv -- "$path" "$newpath" && printf 'renamed: %s -> %s\n' "$path" "$newpath"
    fi
  done
done
