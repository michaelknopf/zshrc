@/Users/mknopf/code/github/savi/claude-code-plugins/plugins/savi/docs/general-principles.md
@/Users/mknopf/code/github/savi/claude-code-plugins/plugins/savi/docs/python-principles.md
@/Users/mknopf/code/github/savi/claude-code-plugins/plugins/savi/docs/type-safety-principles.md
@/Users/mknopf/code/github/savi/claude-code-plugins/plugins/savi/docs/infrastructure-guide.md

# Local Repo Layout

All local clones live under `~/code/github/<org>/<folder>`. When I refer to a repo by a bare name (e.g. "phony", "pybase"), resolve it by checking `~/code/github/savi/<name>` first (that's where most work happens), then the other orgs: `michaelknopf`, `whisprs`, `SigNoz`, `open-telemetry`.

The local folder name often differs from the GitHub repo name — typically the folder drops the `savi-` prefix or shortens further. Examples: `~/code/github/savi/pybase` is `savisec/savi-python-base`, `~/code/github/savi/pypack` is `savisec/savi-pypack`, `~/code/github/savi/phony` is `savisec/savi-phony-svc`, `~/code/github/savi/comp` is `savisec/savi-compose`, `~/code/github/savi/pytools` is `savisec/savi-pytools`. Use these as examples of the pattern; infer other aliases by stripping the `savi-`/`savi-*-svc` affixes, and confirm by reading `.git/config` when uncertain.

**Do not rely on `../<name>` to find sibling repos.** Always resolve repo references via their absolute `~/code/github/<org>/<name>` path. Worktrees may live anywhere, so never assume a worktree's parent directory contains other repos.

# Markdown Output Formatting

When writing markdown content — including plan files, documentation, PR descriptions, comments, and any other prose output — do NOT insert hard line breaks inside paragraphs. Let paragraphs be single long lines and rely on the renderer (Claude Code's plan preview, GitHub, terminals) to soft-wrap based on actual width.
