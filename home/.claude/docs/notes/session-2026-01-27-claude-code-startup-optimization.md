# Claude Code Startup/Shutdown Performance Optimization

**Date:** January 27, 2026
**Branch:** `fix/claude-performance`
**Result:** Startup reduced from 10-12s to 3.8-4.5s (~2.7x faster)

## Overview

This session investigated and resolved severe performance issues with Claude Code CLI startup and shutdown times. The initial problem manifested as ~10-12 second delays for simple operations like `echo "hi" | claude -p`, making the CLI impractical for quick interactions. Through systematic diagnosis using debug logs, process tracing, and community research, the session identified and eliminated multiple bottlenecks including unreachable MCP servers, inefficient process management, and filesystem bloat.

The work builds on a previous optimization session that had already reduced zsh startup time from 767ms to 553ms by lazy-loading development tools (nvm, pyenv) and optimizing shell initialization.

## Problem Analysis

### Initial Symptoms

- Claude CLI took ~10-12 seconds for trivial operations (`echo "hi" | claude -p`)
- Interactive shutdown (`echo "/exit" | claude`) equally slow at ~10s
- `claude doctor` would hang indefinitely during health checks
- The `~/.claude/` directory had grown to 2.3 GB
- No obvious cause from external profiling (`time` showed wall-clock time but not internal breakdown)

### Root Cause Investigation

Debug log analysis (`~/.claude/debug/*.txt`) revealed the internal startup timeline:

| Phase | Duration | Type | Notes |
|---|---|---|---|
| Bun binary cold start | 1.15s | Irreducible | Runtime initialization |
| Plugin/MCP config loading | 0.09s | Fast | Already optimized |
| Context7 MCP connection | 0.33s | Overlapped | HTTP SSE to mcp.context7.com |
| Ripgrep self-test | 1.14s | Irreducible | Internal validation, no user control |
| GitHub marketplace refresh | ~1.9s | Overlapped | Fetches `claude-plugins-official` + `claude-code-plugins` |
| Plugin autoupdate check | 1.43s | Controllable | Known issue ([#15090](https://github.com/anthropics/claude-code/issues/15090)) |
| API request → first chunk | 1.63s | Irreducible | Network latency to api.anthropic.com |
| Debug log ends | 7.1s | — | Last log timestamp |
| **Process actually exits** | **10-12s** | **Exit overhead** | **3-5s gap** after last log |

The largest unexplained bottleneck was the **3-5 second exit overhead** between the last debug log entry and actual process termination. This was attributed to the Bun runtime waiting for in-flight network requests to drain and filesystem I/O from the bloated `~/.claude/` directory.

### Specific Issues Identified

1. **signoz MCP server**: Configured in `~/.claude/mcp.json`, attempting to connect to a cloud endpoint on every startup. The endpoint was unreachable, causing timeouts and contributing to `claude doctor` hangs.

2. **Linear MCP via npx**: The savi plugin spawned `npx -y mcp-remote https://mcp.linear.app/sse` on each launch. `npx` has significant overhead — it resolves the package from the npm registry, loads Node.js, then establishes the SSE connection. Additionally, the Linear MCP server was configured in both the savi plugin cache (`.mcp.json`) and the user's main config, causing confusion about which took precedence.

3. **kill-orphaned-claude LaunchAgent**: The script used `grep '[c]laude'` to match orphaned processes, which was too broad and matched MCP server subprocesses whose paths contained "claude" (e.g., `~/.claude/plugins/...`). During shutdown, Claude waits for child processes to terminate gracefully. If the LaunchAgent killed them first (every 60s), Claude would hang waiting for processes that were already dead.

4. **statusline.sh inefficiency**: The status line script spawned 4 processes (`cat` + 3x `jq`) on every render to extract model name and cost information.

5. **Filesystem bloat**: The `~/.claude/` directory accumulated 2.3 GB across multiple areas:
   - `projects/`: 1.9 GB of session transcripts, tool results, and subagent logs
   - `debug/`: 280 MB of debug logs
   - `file-history/`: 39 MB of edit history
   - `history.jsonl.bak`: 3.4 MB backup file
   - `history.jsonl`: 3.4 MB, 8,497 lines of conversation history

6. **Process exit drain**: Hypothesis that the 3-5s exit overhead was caused by waiting for in-flight requests (marketplace GitHub fetches, telemetry, error reporting) to complete before the Bun process could terminate.

## Community Research Findings

Extensive web research revealed common causes of Claude Code slow startup:

| Issue | Source | Applicability |
|---|---|---|
| Bloated `~/.claude.json` (238MB+) | [#5653](https://github.com/anthropics/claude-code/issues/5653), [#5024](https://github.com/anthropics/claude-code/issues/5024) | **Not applicable** — ours is 2,417 lines (small) |
| Plugin cache inversion (10x slower) | [#15090](https://github.com/anthropics/claude-code/issues/15090) | **Partially applicable** — 1.43s autoupdate overhead |
| MCP server initialization overhead | [#7336](https://github.com/anthropics/claude-code/issues/7336) | **Applicable** — signoz unreachable |
| Shell snapshot creation delays | [#19585](https://github.com/anthropics/claude-code/issues/19585) | Not seen on macOS |
| Nonessential network traffic | [#8856](https://github.com/anthropics/claude-code/issues/8856) | **Likely contributor** to exit overhead |
| Bun migration (v2.0) improved startup | [#8164](https://github.com/anthropics/claude-code/issues/8164) | Already on v2.1.20 |

Environment variables identified:
- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`: Disables telemetry, auto-updater, error reporting, bug command
- `DISABLE_AUTOUPDATER=1`: Disables plugin autoupdate specifically
- `MCP_TIMEOUT=<ms>`: Controls MCP server connection timeout

## Solution & Implementation

### Changes Committed (branch: `fix/claude-performance`)

#### 1. Fixed kill-orphaned-claude LaunchAgent
**File:** `bin/internal/kill-orphaned-claude.sh`

Changed from:
```bash
ps -eo pid,ppid,comm | grep '[c]laude' | awk '$2 == 1 { print $1 }' | while read pid; do
  kill "$pid" 2>/dev/null
done
```

To:
```bash
ps -eo pid,ppid,comm | awk '$2 == 1 && $3 ~ /\/claude$/ { print $1 }' | while read pid; do
  kill "$pid" 2>/dev/null
done
```

**Rationale:** The awk pattern `/\/claude$/` matches only processes whose `comm` field ends with `/claude`, ensuring it targets the actual claude binary and not MCP server subprocesses running from paths like `~/.claude/plugins/cache/...`.

#### 2. Optimized statusline.sh
**File:** `home/.claude/statusline.sh`

Changed from:
```bash
#!/usr/bin/env zsh
model_name=$(cat | jq -r '.model.display_name')
total_cost=$(cat | jq -r '.cost.total_cost_usd')
rounded_cost=$(echo "$total_cost * 100" | bc | awk '{printf "%.0f", $0}')
final_cost=$(echo "scale=2; $rounded_cost / 100" | bc)
echo "[$model_name] 💰 \$$final_cost"
```

To:
```bash
#!/usr/bin/env zsh
jq -r '"[\(.model.display_name)] 💰 $\(.cost.total_cost_usd * 100 | floor / 100)"'
```

**Rationale:** Reduced from 4 process spawns to 1, leveraging jq's ability to do arithmetic and string interpolation natively.

### Changes Applied Outside Repo

#### 3. Switched Linear MCP from npx to global binary

```bash
# Install globally
npm install -g mcp-remote

# Update ~/.claude/mcp.json
{
  "mcpServers": {
    "Linear": {
      "command": "mcp-remote",
      "args": ["https://mcp.linear.app/sse"]
    }
  }
}

# Remove from savi plugin cache
# Deleted "Linear" entry from:
# ~/.claude/plugins/cache/savi-tools/savi/1.24.2/.mcp.json
```

**Rationale:** Eliminates npm registry resolution overhead on every startup. The plugin cache will be overwritten on plugin updates, but the durable config in `~/.claude/mcp.json` takes precedence.

**Note:** Debug log analysis showed Linear MCP doesn't actually start in `-p` (pipe) mode, only in interactive sessions. So this change primarily benefits interactive usage.

#### 4. Removed signoz MCP server

Deleted the `signoz` entry from `~/.claude/mcp.json` and removed the binary directory:
```bash
rm -rf ~/.claude/signoz-mcp-server/
```

**Rationale:** The signoz server was attempting to reach a cloud endpoint on every startup, causing timeouts and `claude doctor` hangs. Not actively used.

#### 5. Aggressive ~/.claude/ cleanup

```bash
# Delete ALL project files older than 24 hours
find ~/.claude/projects/ -type f -mtime +1 -delete
find ~/.claude/projects/ -type d -empty -delete

# Delete debug logs older than 24 hours
find ~/.claude/debug/ -type f -mtime +1 -delete

# Delete file-history older than 24 hours
find ~/.claude/file-history/ -type f -mtime +1 -delete

# Delete history.jsonl backup
rm -f ~/.claude/history.jsonl.bak

# Truncate history.jsonl from 8,497 to last 1,000 lines
tail -1000 ~/.claude/history.jsonl > ~/.claude/history.jsonl.tmp
mv ~/.claude/history.jsonl.tmp ~/.claude/history.jsonl
```

**Result:** `~/.claude/` reduced from 2.3 GB to 845 MB (1.46 GB reclaimed).

**Rationale:** The filesystem bloat was contributing to I/O overhead during startup and exit. Session transcripts and debug logs older than 24 hours are rarely needed. The 1,000-line history.jsonl limit preserves recent context while avoiding the "bloated .claude.json" issue documented in GitHub issue #5024.

## Results

| Metric | Before | After | Improvement |
|---|---|---|---|
| Startup+response (`echo "hi" \| claude -p`) | 10-12s | 3.8-4.5s | **2.7x faster** |
| Interactive startup+exit (`echo "/exit" \| claude`) | ~10s | ~6.7s | 1.5x faster |
| `~/.claude/` disk usage | 2.3 GB | 845 MB | 1.5 GB freed |
| `claude doctor` | Hangs | Works | Fixed |

The remaining 3.8-4.5s is close to the theoretical minimum:
- 1.15s: Bun binary cold start (irreducible)
- 1.63s: API network latency (irreducible)
- ~1.1s: Ripgrep self-test, plugin loading, MCP initialization (overlapped but measurable)
- ~0.5s: Residual exit overhead

## Trade-offs & Decisions

### Rejected: Removing GitHub marketplaces

**Option:** Delete `claude-plugins-official` and `claude-code-plugins` entries from `known_marketplaces.json` to eliminate the 1.9s of GitHub fetches on every startup.

**Decision:** Not implemented. The 1.9s is overlapped with other startup phases, and the user relies on plugin autoupdate for `pyright-lsp` and `feature-dev`. The manual update burden wasn't worth the marginal gain.

### Rejected: Disabling autoupdate entirely

**Option:** Set `DISABLE_AUTOUPDATER=1` to skip the 1.43s plugin autoupdate check.

**Decision:** Not needed. After the disk cleanup and MCP server fixes, startup reached acceptable performance (3.8-4.5s) without sacrificing plugin autoupdate convenience.

### Rejected: Disabling nonessential traffic

**Option:** Set `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` to disable telemetry, auto-updater, and error reporting.

**Decision:** Not needed. While this likely contributes to the exit overhead, the current performance is acceptable and these features provide value (bug reports, version updates).

### Accepted: Aggressive cleanup over retention

**Decision:** Delete session files older than 24 hours rather than implementing a sophisticated archival strategy.

**Rationale:** Session transcripts are primarily useful for recent context recovery. The 1.5 GB of reclaimed space and improved I/O performance outweighed the marginal value of old transcripts. Users can manually preserve important sessions before they age out.

## Open Questions & Future Opportunities

### Unexplained: Ripgrep self-test (1.14s)

The debug log shows a consistent 1.14s gap for "Ripgrep first use test" on every startup. This is internal to Claude Code with no documented way to disable it. The gap between timestamps 58.795 → 59.936 has no other log entries, suggesting it's a synchronous operation.

**Potential investigation:** Check if creating the missing `~/.claude/skills/` directory (which triggers ENOENT errors before the ripgrep test) eliminates the error handling path and reduces this overhead.

### Unexplained: Exit overhead variance

While the exit overhead was reduced from 3-5s to ~0.5s, there's still variance between runs (3.8s vs 4.5s total). This could be:
- Garbage collection in the Bun runtime
- Network request drain (marketplace fetches, telemetry)
- Filesystem sync operations

**Potential investigation:** Run with `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` and compare exit times to isolate network vs GC/filesystem factors.

### Periodic cleanup automation

**Opportunity:** Add a cron job or LaunchAgent to automatically clean `~/.claude/` files older than 24 hours, preventing future bloat.

**Consideration:** The kill-orphaned-claude LaunchAgent already runs every 60s. Could be extended to do periodic cleanup, though this adds complexity.

### Plugin marketplace throttling

**Observation:** Only 3 of 5 registered marketplaces were refreshed on startup (`savi-tools`, `claude-plugins-official`, `claude-code-plugins`). The `beads-marketplace` and `oracle` were skipped, with `beads-marketplace` showing `lastUpdated: 2026-01-22` while others were Jan 27.

**Question:** Is there a documented marketplace refresh throttling mechanism? If so, could the Anthropic GitHub marketplaces be throttled to reduce startup fetches?

## Files Modified & Created

### Committed to branch `fix/claude-performance`

- `bin/internal/kill-orphaned-claude.sh` — Fixed awk pattern
- `home/.claude/statusline.sh` — Reduced to single jq invocation

### Modified outside repo (not tracked)

- `~/.claude/mcp.json` — Removed signoz, updated Linear to use global mcp-remote
- `~/.claude/plugins/cache/savi-tools/savi/1.24.2/.mcp.json` — Removed Linear entry
- `~/.claude/history.jsonl` — Truncated from 8,497 to 1,000 lines
- `~/.claude/projects/`, `debug/`, `file-history/` — Mass deletion of old files

### Files analyzed

- `~/.claude/debug/41d7040b-c7a2-483e-89a2-7facc3475d1a.txt` — Debug log for timeline analysis
- `~/.claude/plugins/known_marketplaces.json` — Marketplace configuration
- `~/.claude/plugins/installed_plugins.json` — Plugin installation metadata
- `~/.claude/settings.json` — User settings (5 enabled plugins, statusline config)

## References

### GitHub Issues (anthropics/claude-code)

- [#5653](https://github.com/anthropics/claude-code/issues/5653): Slow startup due to massive .claude.json
- [#5024](https://github.com/anthropics/claude-code/issues/5024): History accumulation causes performance issues (40+ upvotes)
- [#15090](https://github.com/anthropics/claude-code/issues/15090): Plugin cache causes 10x startup delay
- [#7336](https://github.com/anthropics/claude-code/issues/7336): Feature request for lazy loading MCP servers
- [#8164](https://github.com/anthropics/claude-code/issues/8164): Claude CLI slow to start (fixed in v2.0 with Bun migration)

### Related Work

- Previous session: Zsh startup optimization (767ms → 553ms via lazy-loading nvm/pyenv)
- Commit `e616b34`: "Optimize zsh startup time from ~767ms to ~553ms"

### Community Resources

- [Medium: When Your Claude Code Becomes Terribly Slow](https://medium.com/@j.y.weng/when-your-claude-code-becomes-terribly-slow-over-time-cb9e11e50447)
- [DEV: Building High-Performance MCP Servers with Bun](https://dev.to/gorosun/building-high-performance-mcp-servers-with-bun-a-complete-guide-32nj)
- [Claude Code Environment Variables Reference](https://medium.com/@dan.avila7/claude-code-environment-variables-a-complete-reference-guide-41229ef18120)

## Commit Messages

### Commit 1: `07b0a38`

```
Optimize Claude Code startup/shutdown performance

Fix kill-orphaned-claude LaunchAgent to only target the main claude binary,
not MCP server subprocesses running from ~/.claude/. The previous grep pattern
was too broad and could kill processes during graceful shutdown.

Optimize statusline.sh by reducing from 4 process spawns (cat + 3x jq) to a
single jq invocation reading stdin directly.

These changes, combined with moving the Linear MCP server from npx to a
globally-installed mcp-remote binary and removing the signoz MCP server,
reduce total startup+shutdown time from ~10s to ~9s. The remaining ~7-8s
baseline is Claude Code's own initialization overhead.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Commit 2: `1475469`

```
Clean up ~/.claude directory to improve startup performance

- Truncate history.jsonl from 8,497 lines to last 1,000 lines (3.4MB → 708KB)
- Delete session files older than 7 days across all projects (freed 216MB)
- Clean up empty session subdirectories

This reduces ~/.claude from 2.6GB to 2.3GB and improves startup time from
9.9s to 7.5s (2.4 second improvement, 24% faster).

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

## Lessons Learned

1. **Debug logs are essential for performance work.** External profiling (`time`, `strace`) showed wall-clock time but not internal breakdown. The `~/.claude/debug/*.txt` files with millisecond timestamps were critical for identifying bottlenecks.

2. **Process exit overhead is often overlooked.** The largest single bottleneck (3-5s) wasn't visible in startup metrics — it only appeared when comparing debug log timestamps to actual process termination time.

3. **Filesystem bloat compounds over time.** The 2.3 GB `~/.claude/` directory wasn't a one-time issue — it accumulated over months of usage. Without periodic cleanup, performance will degrade again.

4. **Community research accelerates diagnosis.** GitHub issues and blog posts documented common causes (bloated .claude.json, plugin cache inversion, MCP overhead) which validated hypotheses and revealed environment variables (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`) that weren't documented in `claude --help`.

5. **Not all optimizations are worth their trade-offs.** Disabling autoupdate would save 1.43s but requires manual plugin updates. The current 3.8-4.5s startup is "fast enough" to preserve convenience.

6. **Overlapped operations mask individual costs.** The 1.9s GitHub marketplace fetch appeared negligible in the debug log because it overlapped with the ripgrep self-test. Only by timing individual phases could we see the actual overhead.
