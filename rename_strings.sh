#!/usr/bin/env bash
#
# rename_strings.sh (v4) — recursively replace OLD with NEW both INSIDE FILES
# and in FILE/FOLDER NAMES, for one or more OLD/NEW pairs. Matching of OLD is
# CASE-INSENSITIVE; the result is written in the exact casing of NEW. Case-only
# changes (e.g. addw -> ADDW) are supported.
#
# Usage:
#   ./rename_strings.sh [options] OLD1 NEW1 [OLD2 NEW2 ...]
#     -n, --dry-run     show what would change, modify nothing
#     --names-only      only rename files/folders (skip file contents)
#     --content-only    only edit file contents (skip renaming)
#
# Example:
#   ./rename_strings.sh cache_TagUnit_Par cache_TagUnit_Parallel addw Adder_Wide
#
# Safeguards (stop a partial match like cache_TagUnit_Par -> ..._Parallel from
# being applied twice):
#   * Contents: an occurrence is replaced only when it is NOT already the start
#     of NEW (negative lookahead on NEW's trailing part). A file can therefore
#     contain both OLD and NEW; only the OLD ones change.
#   * Names: an entry whose name already contains NEW is skipped. The name
#     check is case-insensitive for a normal pair (an already-NEW name in any
#     casing is protected) and case-sensitive for a case-only pair (so the
#     files actually get re-cased).
# Binaries and .git are skipped. Files with no real change are not rewritten.
#
# Requires bash >= 4 and perl.

set -uo pipefail
shopt -s nocasematch

# Fail clearly on a bash too old for case-insensitive ${var//...} (e.g. macOS
# system bash 3.2) instead of silently skipping files.
_probe="ABC"
if [[ "${_probe//abc/X}" != "X" ]]; then
  echo "error: this bash lacks case-insensitive \${var//...}; use bash >= 4." >&2
  exit 1
fi
command -v perl >/dev/null || { echo "error: perl is required." >&2; exit 1; }

dry_run=0
do_names=1
do_content=1
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -n|--dry-run)   dry_run=1 ;;
    --names-only)   do_content=0 ;;
    --content-only) do_names=0 ;;
    --)             shift; break ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ $do_names -eq 0 && $do_content -eq 0 ]]; then
  echo "error: --names-only and --content-only are mutually exclusive." >&2
  exit 1
fi
if [[ $# -lt 2 || $(( $# % 2 )) -ne 0 ]]; then
  echo "Usage: $0 [-n|--dry-run] [--names-only|--content-only] OLD1 NEW1 ..." >&2
  exit 1
fi

# perl program: build a case-insensitive regex for OLD. If LOOK=1, add a
# negative lookahead on SUF so an already-NEW occurrence is left alone.
read -r -d '' PERL_SUBST <<'PERL' || true
BEGIN { $o = $ENV{OLD}; $s = $ENV{SUF}; $n = $ENV{NEW};
        $re = ($ENV{LOOK} eq "1") ? qr/\Q$o\E(?!\Q$s\E)/i : qr/\Q$o\E/i; }
s/$re/$n/g;
PERL
read -r -d '' PERL_COUNT <<'PERL' || true
BEGIN { $o = $ENV{OLD}; $s = $ENV{SUF};
        $re = ($ENV{LOOK} eq "1") ? qr/\Q$o\E(?!\Q$s\E)/i : qr/\Q$o\E/i; }
my $c = () = /$re/g; print $c;
PERL

while [[ $# -ge 2 ]]; do
  old=$1
  new=$2
  shift 2

  if [[ -z "$old" ]]; then
    echo "skip: empty OLD string" >&2
    continue
  fi
  # True duplicate (byte-identical) -> nothing to do. [ = ] stays
  # case-sensitive regardless of nocasematch, so a case-only pair is kept.
  if [ "$old" = "$new" ]; then
    echo "skip: OLD == NEW ('$old')" >&2
    continue
  fi

  # Lookahead only when NEW is strictly longer than OLD and starts with OLD
  # (case-insensitively) -- the prefix-collision case (Par -> Parallel).
  suffix=""
  look=0
  old_lc=${old,,}
  new_lc=${new,,}
  if [[ ${#new} -gt ${#old} && "${new_lc:0:${#old}}" == "$old_lc" ]]; then
    suffix=${new:${#old}}
    look=1
  fi

  echo "== pair: '$old' -> '$new' (case-insensitive match) =="

  # ---- contents ----
  if [[ $do_content -eq 1 ]]; then
    # -I skips binaries, -i case-insensitive, -F literal OLD, -Z null output.
    grep -rlIiFZ --exclude-dir=.git -e "$old" . 2>/dev/null |
    while IFS= read -r -d '' file; do
      n=$(OLD="$old" SUF="$suffix" LOOK="$look" perl -0777 -ne "$PERL_COUNT" "$file" 2>/dev/null)
      n=${n:-0}
      [[ "$n" =~ ^[0-9]+$ ]] || n=0
      [[ "$n" -gt 0 ]] || continue   # only already-NEW occurrences: skip rewrite
      if [[ $dry_run -eq 1 ]]; then
        printf 'edit (dry): %s replacement(s) in %s\n' "$n" "$file"
      else
        OLD="$old" NEW="$new" SUF="$suffix" LOOK="$look" \
          perl -0777 -i -pe "$PERL_SUBST" "$file" &&
          printf 'edited: %s replacement(s) in %s\n' "$n" "$file"
      fi
    done
  fi

  # ---- names ----
  if [[ $do_names -eq 1 ]]; then
    # Name-safeguard sensitivity: case-sensitive for a case-only pair (so files
    # get re-cased), case-insensitive otherwise (protect already-NEW names).
    if [[ "$old" == "$new" ]]; then
      guard_flags=(-qF)
    else
      guard_flags=(-qiF)
    fi
    # -depth: rename children before parents. -iname: match basename, any case.
    find . -depth -not -path './.git/*' -iname "*$old*" -print0 |
    while IFS= read -r -d '' path; do
      base=$(basename "$path")
      if printf '%s' "$base" | grep "${guard_flags[@]}" -e "$new"; then
        continue
      fi
      newbase=${base//"$old"/"$new"}
      newpath="$(dirname "$path")/$newbase"
      if [[ -e "$newpath" ]]; then
        echo "skip: target already exists: $newpath" >&2
        continue
      fi
      if [[ $dry_run -eq 1 ]]; then
        printf 'rename (dry): %s -> %s\n' "$path" "$newpath"
      else
        mv -- "$path" "$newpath" && printf 'renamed: %s -> %s\n' "$path" "$newpath"
      fi
    done
  fi
done
