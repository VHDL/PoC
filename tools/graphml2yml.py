#!/usr/bin/env python3
"""Generate a poc.tcl YAML dependency file from a compile-order graphml
file, then layer in constraint-file dependencies.

Usage:
  graphml2yml.py                                    # <pocRoot>/compileorder.graphml
  graphml2yml.py /path/to/other.graphml
  graphml2yml.py /path/to/other.graphml /path/to/other.overrides.yml

Output is written next to this script, named after the graphml input (e.g.
compileorder.graphml -> compileorder.yml) -- not into any tool-specific
folder. Move it to the right place (e.g. tools/Vivado/) by hand.

Manual exceptions: a second argument gives the overrides file's path
explicitly; if omitted, defaults to <graphml-stem>.overrides.yml next to
this script (e.g. compileorder.overrides.yml). If present, it is applied on
top of the generated entries before writing -- see apply_overrides() for the
exact merge rules. This survives regeneration, since it's a separate
hand-written file the generator only ever reads, never touches.

Edge semantics in the graphml file:
  source="A" target="B"  means  A DEPENDS ON B  (B must compile first).
So for each node A, its dependsOn list = targets of edges where source=A.
Every entry produced from the graph is tagged kind: VHDLSourceFile.

Constraint files (ucf/**/*.xdc) are NOT part of the graphml file at all --
there is no node or edge for them.  A separate, disk-driven pass scans ucf/
after the VHDL entries are built: for every *.xdc whose namespace+basename
matches an existing VHDL entry's key (e.g. ucf/sync/sync_Command.xdc ->
PoC.sync.sync_Command), a new kind: XDCConstraintFile entry is created --
scoped to that VHDL entity via the SCOPED_TO_REF attribute -- and linked into the VHDL
entry's dependsOn list, so poc_Add pulls the constraint in automatically.
*.xdc files with no matching VHDL entry (mostly per-board pin/clock constraint
sets under ucf/<Board>/) are reported and left out; there is no core to scope
them to.
"""

import sys
from pathlib import Path
from collections import defaultdict
import re

SCRIPT_VERSION = "1.3"

# kind: values written into the YAML and matched by poc.tcl's switch.
KIND_VHDL       = "VHDLSourceFile"
KIND_CONSTRAINT = "XDCConstraintFile"


def find_sources(poc_root: Path) -> dict[str, Path]:
    """Return {basename → relative_path} for every .vhdl file under src/."""
    src_dir = poc_root / "src"
    mapping: dict[str, Path] = {}
    for vhdl in src_dir.rglob("*.vhdl"):
        name = vhdl.name
        if name in mapping:
            print(f"WARNING: duplicate filename {name!r} — keeping first", file=sys.stderr)
        else:
            mapping[name] = vhdl.relative_to(poc_root)
    return mapping


def path_to_key(relpath: Path) -> str:
    """<root>/ns1[/ns2]/file.ext  →  PoC.ns1[.ns2].basename, with the
    redundant last-namespace-segment prefix stripped from the basename
    (e.g. src/sync/sync_Bits.vhdl -> PoC.sync.Bits, not PoC.sync.sync_Bits).

    Special case: a namespace's own canonical package, <ns>/<ns>.pkg.vhdl,
    becomes PoC...<ns>.pkg rather than the doubled PoC...<ns>.<ns>.pkg --
    e.g. src/sync/sync.pkg.vhdl -> PoC.sync.pkg, not PoC.sync.sync.pkg.
    Deliberately NOT collapsed further to the bare namespace (PoC.sync):
    that would make the package's short name identical to the namespace
    segment itself, which shadows poc.tcl's _resolveAll namespace-group
    matching (poc add sync would then mean "just the package" instead of
    "everything under PoC.sync.*").
    """
    parts = list(relpath.parts)   # ['src', 'common', 'utils.vhdl']
    ns_parts = parts[1:-1]        # ['common'] or ['mem', 'ocram']
    stem = Path(parts[-1]).stem
    last_ns = ns_parts[-1] if ns_parts else None

    if last_ns and stem == f"{last_ns}.pkg":
        basename = "pkg"
    elif last_ns and stem.startswith(f"{last_ns}_"):
        basename = stem[len(last_ns) + 1:]
    else:
        basename = stem

    return "PoC." + ".".join(ns_parts + [basename])


def _fail_on_key_collision(entries: dict[str, dict], key: str, new_relpath: str) -> None:
    """Fatal error if `key` is already claimed by a *different* source file.

    Without this, a colliding key would silently overwrite the earlier
    entry in `entries` -- one IP core would just vanish from the generated
    file with no indication why. Most likely to bite as new IPs are added:
    e.g. two source files that both reduce to the same key once
    path_to_key()'s namespace-prefix-stripping and .pkg rules are applied.
    """
    existing = entries.get(key)
    if existing is None:
        return
    existing_file = existing["sources"][0]["file"] if existing.get("sources") else "?"
    if existing_file == new_relpath:
        return  # same file processed twice -- not a collision

    print(f"ERROR: key collision on '{key}':", file=sys.stderr)
    print(f"       {existing_file}", file=sys.stderr)
    print(f"       {new_relpath}", file=sys.stderr)
    print("       Both files map to the same generated key -- rename one of "
          "them, or adjust path_to_key().", file=sys.stderr)
    sys.exit(1)


def parse_graphml(path: Path) -> tuple[list[str], dict[str, list[str]]]:
    """Return (ordered_node_ids, {source: [target, ...]})."""
    content = path.read_text(encoding="utf-8")

    nodes: list[str] = re.findall(r'<node\s+id="([^"]+)"', content)

    edges: dict[str, list[str]] = defaultdict(list)
    for m in re.finditer(r'<edge\b[^>]*\bsource="([^"]+)"[^>]*\btarget="([^"]+)"', content):
        edges[m.group(1)].append(m.group(2))

    return nodes, edges


def build_vhdl_entries(nodes: list[str], edges: dict[str, list[str]],
                        file_to_relpath: dict[str, Path]) -> tuple[dict[str, dict], list[str]]:
    """Return ({key: entry}, skipped_node_names) for every VHDL node found on disk.

    entry = {"kind": KIND_VHDL, "sources": [{"file": relpath_str}], "dependsOn": [key, ...]}
    Dict insertion order follows the graphml node order (compile order).
    """
    file_to_key = {f: path_to_key(p) for f, p in file_to_relpath.items()}

    entries: dict[str, dict] = {}
    skipped: list[str] = []

    for filename in nodes:
        if filename not in file_to_relpath:
            skipped.append(filename)
            continue

        relpath  = file_to_relpath[filename]
        key      = file_to_key[filename]
        dep_keys = [file_to_key[t] for t in edges.get(filename, [])
                    if t in file_to_key]

        _fail_on_key_collision(entries, key, relpath.as_posix())
        entries[key] = {
            "kind": KIND_VHDL,
            "sources": [{"file": relpath.as_posix()}],
            "dependsOn": dep_keys,
        }

    return entries, skipped


def find_constraint_files(poc_root: Path) -> list[Path]:
    """Return every .xdc file under ucf/ as a relative path.

    Unlike VHDL sources, constraint filenames are NOT globally unique --
    per-board directories legitimately reuse names like GPIO.LED.xdc -- so
    this must not dedupe by basename, only return full relative paths.
    """
    ucf_dir = poc_root / "ucf"
    return [xdc.relative_to(poc_root) for xdc in sorted(ucf_dir.rglob("*.xdc"))]


def apply_constraints(entries: dict[str, dict], poc_root: Path) -> list[str]:
    """Layer ucf/**/*.xdc constraint files onto the VHDL entries in place.

    Returns the list of *.xdc relative paths that had no matching VHDL entry.
    """
    unmatched: list[str] = []

    for relpath in find_constraint_files(poc_root):
        vhdl_key = path_to_key(relpath)
        if vhdl_key not in entries:
            unmatched.append(relpath.as_posix())
            continue

        entity_name    = relpath.stem
        constraint_key = f"{vhdl_key}.xdc"

        _fail_on_key_collision(entries, constraint_key, relpath.as_posix())
        entries[constraint_key] = {
            "kind": KIND_CONSTRAINT,
            "sources": [{
                "file": relpath.as_posix(),
                "attributes": {"SCOPED_TO_REF": entity_name},
            }],
            "dependsOn": [],
        }
        entries[vhdl_key]["dependsOn"].append(constraint_key)

    return unmatched


def load_overrides(overrides_path: Path) -> dict:
    """Load a sparse manual-overrides YAML file (see apply_overrides), or {}
    if it doesn't exist.

    Only imports PyYAML here, not at module scope -- running without an
    overrides file (the common case) needs no extra dependency beyond the
    stdlib the rest of this script already sticks to.
    """
    if not overrides_path.exists():
        return {}

    try:
        import yaml
    except ImportError:
        print(f"ERROR: {overrides_path} exists but PyYAML is not installed.",
              file=sys.stderr)
        print("       Install it with: pip install pyyaml", file=sys.stderr)
        sys.exit(1)

    with overrides_path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def apply_overrides(entries: dict[str, dict], overrides: dict) -> tuple[int, int, int]:
    """Apply a sparse overrides mapping onto entries, in place.

    Each top-level key in `overrides` is a core key, same as in `entries`:
      - value is ~ (None)   -> delete that entry entirely, if present; else
                                print a warning (nothing to delete -- likely
                                a typo or an already-gone/renamed node).
      - key not in entries  -> insert the override as a brand-new entry, but
                                print a warning either way -- since it's not
                                in the generated graph, this is either a
                                deliberate new node or a mistake (typo in the
                                override, or a node missing from the
                                graphml), and only you can tell which. Must
                                be complete (kind/sources/dependsOn) -- there
                                is nothing to merge onto -- else it's always
                                an error, not just a warning.
      - key already exists  -> merge onto the existing entry:
          - "kind" / "dependsOn", if given, replace that field wholesale.
          - "sources", if given: each item is matched onto the existing
            source with the same "file" (appended if no match). Fields
            given on a matched item (e.g. "attributes", "vhdlVersion")
            replace the existing value wholesale -- they are not merged
            any deeper (e.g. giving "attributes" replaces the whole map,
            it does not add to it).

    Returns (modified, added, removed) counts, for the caller to report.
    """
    modified = added = removed = 0

    for key, override_entry in overrides.items():
        if override_entry is None:
            if entries.pop(key, None) is not None:
                removed += 1
            else:
                print(f"WARNING: override removes '{key}', but no such entry "
                      f"exists (typo, or already gone from the graph?)", file=sys.stderr)
            continue

        for osrc in override_entry.get("sources", []):
            _check_override_source(key, osrc)

        if key not in entries:
            missing = [f for f in ("kind", "sources", "dependsOn") if f not in override_entry]
            if missing:
                print(f"ERROR: override adds new entry '{key}' but is missing "
                      f"required field(s): {', '.join(missing)}", file=sys.stderr)
                sys.exit(1)
            print(f"WARNING: override adds '{key}', which is not in the generated "
                  f"graph -- confirm this is intentional (not a typo, or a node "
                  f"missing from the graphml)", file=sys.stderr)
            entries[key] = override_entry
            added += 1
            continue

        base_entry = entries[key]
        if "kind" in override_entry:
            base_entry["kind"] = override_entry["kind"]
        if "dependsOn" in override_entry:
            base_entry["dependsOn"] = override_entry["dependsOn"]
        if "sources" in override_entry:
            base_by_file = {s["file"]: s for s in base_entry.get("sources", [])}
            for osrc in override_entry["sources"]:
                existing = base_by_file.get(osrc["file"])
                if existing is not None:
                    existing.update(osrc)
                else:
                    base_entry.setdefault("sources", []).append(osrc)
        modified += 1

    return modified, added, removed


def _check_override_source(key: str, osrc: dict) -> None:
    """Validate one override source item before it's merged in, so a typo'd
    override (e.g. a missing colon turning a map into a plain string) fails
    here with a clear message instead of crashing write_yml much later with
    an opaque AttributeError.
    """
    if "file" not in osrc:
        print(f"ERROR: override for '{key}' has a source with no 'file' field: {osrc}",
              file=sys.stderr)
        sys.exit(1)

    attrs = osrc.get("attributes")
    if attrs is not None and not isinstance(attrs, dict):
        print(f"ERROR: override for '{key}' ({osrc['file']}) has a non-map "
              f"'attributes' value: {attrs!r}", file=sys.stderr)
        print("       Likely a missing colon, e.g. 'NAME: value' not 'NAME value'.",
              file=sys.stderr)
        sys.exit(1)


def write_yml(out_path: Path, entries: dict[str, dict]) -> None:
    # version lives at document root, ahead of (and outside) the
    # dependencies: map -- poc.tcl reads it from there directly.
    with out_path.open("w", encoding="utf-8") as f:
        f.write(f'version: "{SCRIPT_VERSION}"\n')
        f.write("dependencies:\n")

        for key, entry in entries.items():
            f.write(f"\n  {key}:\n")
            f.write(f"    kind: {entry['kind']}\n")
            f.write(f"    sources:\n")
            for src in entry["sources"]:
                f.write(f"      - file: {src['file']}\n")
                # Omit vhdlVersion/attributes entirely when not applicable,
                # rather than writing them as ~ -- poc.tcl treats an
                # absent key as "use the default", via a portable
                # huddle-keys-based existence check (see _hasKey).
                vhdl_version = src.get("vhdlVersion")
                if vhdl_version:
                    f.write(f"        vhdlVersion: {vhdl_version}\n")
                attrs = src.get("attributes")
                if attrs:
                    f.write(f"        attributes:\n")
                    for attr_name, attr_val in attrs.items():
                        f.write(f"          {attr_name}: {attr_val}\n")

            if entry["dependsOn"]:
                f.write(f"    dependsOn:\n")
                for dk in entry["dependsOn"]:
                    f.write(f"      - {dk}\n")


def main() -> None:
    script_dir  = Path(__file__).parent
    poc_root    = (script_dir / "..").resolve()
    graphml     = Path(sys.argv[1]) if len(sys.argv) > 1 else poc_root / "compileorder.graphml"
    # Same base name as the graphml input, written next to this script --
    # not tied to any particular tool's folder. Move it to the right place
    # (e.g. tools/Vivado/) by hand once it's built.
    output      = script_dir / (graphml.stem + ".yml")
    overrides_path = (Path(sys.argv[2]) if len(sys.argv) > 2
                       else script_dir / (graphml.stem + ".overrides.yml"))

    if not graphml.exists():
        print(f"ERROR: {graphml} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Reading {graphml} …")
    nodes, edges = parse_graphml(graphml)
    print(f"  {len(nodes)} nodes, {sum(len(v) for v in edges.values())} edges")

    print(f"Scanning {poc_root / 'src'} …")
    file_to_relpath = find_sources(poc_root)
    print(f"  {len(file_to_relpath)} .vhdl files found")

    entries, skipped = build_vhdl_entries(nodes, edges, file_to_relpath)
    if skipped:
        print(f"Skipped {len(skipped)} node(s) not found on disk:", file=sys.stderr)
        for s in skipped:
            print(f"  {s}", file=sys.stderr)

    print(f"Scanning {poc_root / 'ucf'} for constraint files …")
    unmatched = apply_constraints(entries, poc_root)
    linked = sum(1 for e in entries.values() if e["kind"] == KIND_CONSTRAINT)
    print(f"  {linked} constraint file(s) linked to a VHDL entry")
    if unmatched:
        print(f"  {len(unmatched)} constraint file(s) have no matching VHDL entry (skipped):",
              file=sys.stderr)
        for u in unmatched:
            print(f"    {u}", file=sys.stderr)

    overrides = load_overrides(overrides_path)
    if overrides:
        modified, added, removed = apply_overrides(entries, overrides)
        print(f"Applied {overrides_path}: "
              f"{modified} modified, {added} added, {removed} removed")
    else:
        print(f"No overrides file at {overrides_path} (skipped)")

    print(f"Writing {output} …")
    write_yml(output, entries)
    print("Done.")


if __name__ == "__main__":
    main()
