#!/usr/bin/env python3
"""
Add horizontal rules (---) under all level 2+ headings in markdown files.

Usage:
    python add_heading_underlines.py [directory] [--dry-run] [--exclude NAME ...]

Changes from the original version:
    - Skips themes, node_modules, public, resources, .git and .obsidian
    - Preserves each file's existing line endings (no LF -> CRLF rewrite)
    - Only writes a file when its content actually changes
    - Ignores headings inside fenced code blocks
    - --dry-run lists what would change without writing anything
"""

import argparse
import re
import sys
from pathlib import Path

DEFAULT_EXCLUDES = {"themes", "node_modules", "public", "resources", ".git", ".obsidian"}
RULES = {"---", "===", "___", "***"}
HEADING = re.compile(r"^##+ ")
FENCE = re.compile(r"^\s*(```|~~~)")


def underline_headings(lines):
    """Return a new list of lines with --- added under level 2+ headings."""
    out = []
    in_fence = False
    for i, line in enumerate(lines):
        out.append(line)

        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or not HEADING.match(line):
            continue

        next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
        if next_line in RULES:
            continue

        # Reuse the heading's own line ending so the file stays consistent
        if line.endswith("\r\n"):
            eol = "\r\n"
        elif line.endswith("\n"):
            eol = "\n"
        else:
            # Heading is the last line with no trailing newline
            eol = "\r\n" if any(l.endswith("\r\n") for l in lines) else "\n"
            out[-1] = line + eol
        out.append("---" + eol)
    return out


def process_markdown_file(filepath, dry_run=False):
    """Process one file. Returns True if the file changed (or would change)."""
    # newline='' disables newline translation on both read and write
    with open(filepath, "r", encoding="utf-8", newline="") as f:
        lines = f.readlines()

    new_lines = underline_headings(lines)
    if new_lines == lines:
        return False

    if not dry_run:
        with open(filepath, "w", encoding="utf-8", newline="") as f:
            f.writelines(new_lines)
    return True


def find_markdown_files(base_path, excludes):
    files = []
    for pattern in ("*.md", "*.markdown"):
        for path in base_path.rglob(pattern):
            relative_parts = path.relative_to(base_path).parts[:-1]
            if any(part in excludes for part in relative_parts):
                continue
            files.append(path)
    return sorted(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("directory", nargs="?", default=".")
    parser.add_argument("--dry-run", action="store_true",
                        help="show which files would change, write nothing")
    parser.add_argument("--exclude", nargs="*", default=[],
                        help="extra folder names to skip")
    args = parser.parse_args()

    base_path = Path(args.directory)
    if not base_path.is_dir():
        print(f"Error: Directory '{args.directory}' does not exist")
        sys.exit(1)

    excludes = DEFAULT_EXCLUDES | set(args.exclude)
    markdown_files = find_markdown_files(base_path, excludes)
    if not markdown_files:
        print(f"No markdown files found in {args.directory}")
        sys.exit(0)

    print(f"Found {len(markdown_files)} markdown file(s)")
    print(f"Skipping folders: {', '.join(sorted(excludes))}")
    print()

    changed = 0
    for md_file in markdown_files:
        try:
            if process_markdown_file(md_file, dry_run=args.dry_run):
                changed += 1
                verb = "Would change" if args.dry_run else "Changed"
                print(f"  [{verb}] {md_file}")
        except Exception as e:
            print(f"  [Error] {md_file}: {e}")

    print()
    unchanged = len(markdown_files) - changed
    label = "would change" if args.dry_run else "changed"
    print(f"Done. {changed} {label}, {unchanged} left untouched.")


if __name__ == "__main__":
    main()