#!/usr/bin/env python3

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys


NAME_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
SEGMENT_PATTERN = re.compile(r"[A-Za-z0-9._-]+")
URI_PATTERN = re.compile(r"skill://[^\s`<>'\",;)\]}]*")
NAMED_PATTERN = re.compile(r"\*\*([a-z][a-z0-9-]*)\*\*")


@dataclass(frozen=True)
class Reference:
    source: str
    line: int
    column: int
    kind: str
    raw: str
    candidates: tuple[str, ...]
    relative_path: str | None = None
    invalid_code: str | None = None


@dataclass(frozen=True, order=True)
class Finding:
    source: str
    line: int
    column: int
    code: str
    raw: str


def parse_frontmatter_name(manifest: Path) -> str | None:
    lines = manifest.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        return None
    for line in lines[1:]:
        if line == "---":
            break
        if line.startswith("name:"):
            value = line.removeprefix("name:").strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            return value or None
    return None


def build_index(repo: Path, installed_roots: list[Path]) -> tuple[dict[str, tuple[Path, ...]], set[str]]:
    locations: dict[str, list[Path]] = {}
    source_names: set[str] = set()
    source_manifests = sorted((repo / "skills").glob("*/SKILL.md"))
    for manifest in source_manifests:
        name = parse_frontmatter_name(manifest)
        if name:
            locations.setdefault(name, []).append(manifest.parent)
            source_names.add(name)
    for root in installed_roots:
        if not root.is_dir():
            continue
        for manifest in sorted(root.glob("*/SKILL.md")):
            name = parse_frontmatter_name(manifest)
            if name:
                locations.setdefault(name, []).append(manifest.parent)
    return {name: tuple(paths) for name, paths in locations.items()}, source_names


def source_markdown(repo: Path) -> list[Path]:
    paths: list[Path] = []
    readme = repo / "README.md"
    if readme.is_file():
        paths.append(readme)
    for directory in (repo / "agents", repo / "skills"):
        if directory.is_dir():
            paths.extend(directory.rglob("*.md"))
    return sorted(set(paths), key=lambda path: path.relative_to(repo).as_posix())


def parse_uri(source: str, line_number: int, match: re.Match[str]) -> Reference:
    raw = match.group()
    value = raw.removeprefix("skill://")
    parts = value.split("/")
    name = parts[0]
    invalid_code = None
    relative_path = None
    if not NAME_PATTERN.fullmatch(name):
        invalid_code = "URI_INVALID"
    elif len(parts) > 1:
        segments = parts[1:]
        if any(segment in {"", ".", ".."} or not SEGMENT_PATTERN.fullmatch(segment) for segment in segments):
            invalid_code = "URI_PATH_INVALID"
        else:
            relative_path = "/".join(segments)
    return Reference(
        source=source,
        line=line_number,
        column=match.start() + 1,
        kind="uri",
        raw=raw,
        candidates=(name,),
        relative_path=relative_path,
        invalid_code=invalid_code,
    )


def collect_references(repo: Path) -> list[Reference]:
    references: list[Reference] = []
    for path in source_markdown(repo):
        source = path.relative_to(repo).as_posix()
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            references.extend(parse_uri(source, line_number, match) for match in URI_PATTERN.finditer(line))
            for match in NAMED_PATTERN.finditer(line):
                name = match.group(1)
                suffix = line[match.end() :]
                is_principle = bool(re.match(r"\s+principle(?:\s+skill)?\b", suffix)) and not name.startswith("principle-")
                candidates = (f"principle-{name}",) if is_principle else (name,)
                references.append(
                    Reference(
                        source=source,
                        line=line_number,
                        column=match.start() + 1,
                        kind="named",
                        raw=name,
                        candidates=candidates,
                    )
                )
    return references


def exact_file(root: Path, relative_path: str) -> bool:
    current = root
    for segment in relative_path.split("/"):
        entries = {entry.name: entry for entry in current.iterdir()} if current.is_dir() else {}
        if segment not in entries:
            return False
        current = entries[segment]
    resolved_root = root.resolve()
    resolved_target = current.resolve()
    return resolved_target.is_relative_to(resolved_root) and resolved_target.is_file()


def resolve(reference: Reference, index: dict[str, tuple[Path, ...]], source_names: set[str]) -> Finding | None:
    if reference.invalid_code:
        return Finding(reference.source, reference.line, reference.column, reference.invalid_code, reference.raw)
    name = next((candidate for candidate in reference.candidates if candidate in index), None)
    if name is None:
        return Finding(reference.source, reference.line, reference.column, "SKILL_NOT_FOUND", reference.raw)
    if reference.kind == "named" or reference.relative_path is None:
        return None
    if name not in source_names and len(index[name]) > 1:
        return Finding(reference.source, reference.line, reference.column, "SKILL_AMBIGUOUS", reference.raw)
    location = index[name][0]
    if exact_file(location, reference.relative_path):
        return None
    return Finding(reference.source, reference.line, reference.column, "URI_PATH_NOT_FOUND", reference.raw)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Audit skill references against source and installed skill frontmatter.")
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--installed-root", action="append", type=Path, help="Installed skill root to audit")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = args.repo.resolve()
    if not repo.is_dir():
        print(f"Repository does not exist: {repo}", file=sys.stderr)
        return 2
    roots = args.installed_root or [Path.home() / ".claude" / "skills", Path.home() / ".agents" / "skills"]
    try:
        index, source_names = build_index(repo, roots)
        findings = sorted(
            finding
            for reference in collect_references(repo)
            if (finding := resolve(reference, index, source_names)) is not None
        )
    except (OSError, UnicodeError) as error:
        print(str(error), file=sys.stderr)
        return 2
    for finding in findings:
        print(f"{finding.source}:{finding.line}:{finding.column}: {finding.code}: {finding.raw}")
    if findings:
        print(f"FAIL: {len(findings)} unresolved skill references")
        return 1
    print("PASS: all skill references resolve")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
