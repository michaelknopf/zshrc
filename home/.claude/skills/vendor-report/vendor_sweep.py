# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
"""The code half of /vendor-report: which third-party packages and API keys each repo uses.

Walks every repo under a root (the primary clones, skipping worktrees and build output)
and prints JSON with three maps, each from a name to the repos it appears in:

- `packages`: Python (pyproject.toml) and JS (package.json) dependencies. Our own
  packages are excluded: any name starting with the own prefix or a repo's folder name,
  which drops workspace members like `data-lake-posthog`.
- `terraform_providers`: `namespace/name` provider sources.
- `key_settings`: Python classes declaring an API-key-like field, so vendors called
  over plain HTTP with no SDK still show up.

It reports what the code references, not what each name is: mapping names to vendors
is the command's job.

Usage:
    vendor_sweep.py [--own-prefix savi] <root>
"""

import argparse
import json
import re
import sys
import tomllib
from collections import defaultdict
from pathlib import Path

SKIP_DIRS = {
    ".worktrees", "node_modules", ".venv", "cdk.out", ".git", "dist", "build",
    ".terraform", ".playwright-mcp", "testdata", "tests", "test", "__snapshots__",
}
KEY_FIELD = re.compile(
    r"^\s+(?:\w+_)?(api_key|api_token|api_secret|auth_token|license_key|api_key_secret)\s*:"
)
CLASS = re.compile(r"^class (\w+)")
PROVIDER = re.compile(r'source\s*=\s*"([a-z0-9-]+/[a-z0-9-]+)"')
REQUIREMENT_NAME = re.compile(r"[<>=!~\[; @]")


class Sweep:
    def __init__(self, own_prefix: str) -> None:
        self._own: tuple[str, ...] = (own_prefix, f"@{own_prefix}")
        self.packages: defaultdict[str, set[str]] = defaultdict(set)
        self.providers: defaultdict[str, set[str]] = defaultdict(set)
        self.key_settings: defaultdict[str, set[str]] = defaultdict(set)

    def scan(self, root: Path) -> None:
        repos = sorted(p for p in root.iterdir() if p.is_dir() and not p.name.startswith("."))
        self._own += tuple(f"{r.name}-" for r in repos)
        for repo in repos:
            for path in self._files(repo):
                self._scan_file(repo.name, path)

    def as_json(self) -> dict[str, dict[str, list[str]]]:
        def flat(m: dict[str, set[str]]) -> dict[str, list[str]]:
            return {k: sorted(v) for k, v in sorted(m.items())}

        return {
            "packages": flat(self.packages),
            "terraform_providers": flat(self.providers),
            "key_settings": flat(self.key_settings),
        }

    def _files(self, repo: Path):
        stack = [repo]
        while stack:
            d = stack.pop()
            for child in d.iterdir():
                if child.is_dir():
                    if child.name not in SKIP_DIRS:
                        stack.append(child)
                elif child.name in ("pyproject.toml", "package.json") or child.suffix in (".tf", ".py"):
                    yield child

    def _scan_file(self, repo: str, path: Path) -> None:
        try:
            if path.name == "pyproject.toml":
                self._add_packages(repo, self._python_deps(path))
            elif path.name == "package.json":
                self._add_packages(repo, self._js_deps(path))
            elif path.suffix == ".tf":
                for source in PROVIDER.findall(path.read_text()):
                    self.providers[source].add(repo)
            else:
                self._scan_python(repo, path)
        except (OSError, UnicodeDecodeError, ValueError, tomllib.TOMLDecodeError) as e:
            print(f"skipped {path}: {e}", file=sys.stderr)

    def _add_packages(self, repo: str, names: list[str]) -> None:
        for name in names:
            if name and not name.lower().startswith(self._own) and not name.startswith("@types/"):
                self.packages[name.lower()].add(repo)

    @staticmethod
    def _python_deps(path: Path) -> list[str]:
        t = tomllib.loads(path.read_text())
        project = t.get("project", {})
        reqs = list(project.get("dependencies", []))
        for group in project.get("optional-dependencies", {}).values():
            reqs += group
        for group in t.get("dependency-groups", {}).values():
            reqs += [r for r in group if isinstance(r, str)]
        return [REQUIREMENT_NAME.split(r.strip())[0] for r in reqs]

    @staticmethod
    def _js_deps(path: Path) -> list[str]:
        t = json.loads(path.read_text())
        return [*t.get("dependencies", {}), *t.get("devDependencies", {})]

    def _scan_python(self, repo: str, path: Path) -> None:
        cls = None
        for line in path.read_text().splitlines():
            if m := CLASS.match(line):
                cls = m.group(1)
            elif cls and KEY_FIELD.match(line):
                self.key_settings[cls].add(repo)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", type=Path)
    parser.add_argument("--own-prefix", default="savi")
    args = parser.parse_args()
    sweep = Sweep(args.own_prefix)
    sweep.scan(args.root.expanduser())
    json.dump(sweep.as_json(), sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main()
