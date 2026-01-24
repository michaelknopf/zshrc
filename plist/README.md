# LaunchAgents

This directory contains macOS launchd configuration files for background services and scheduled tasks.

## File Convention

Source files are stored with the `.xml` extension to make it clear they are XML documents. They are symlinked into `~/Library/LaunchAgents/` with the `.plist` extension for launchd to recognize them.

## Installation

To install a launchd agent:

1. Create a symlink in `~/Library/LaunchAgents/` pointing to the `.xml` source file:
   ```bash
   ln -s /Users/mknopf/code/github/michaelknopf/zshrc/plist/<name>.xml ~/Library/LaunchAgents/<name>.plist
   ```

2. Load the agent:
   ```bash
   launchctl load ~/Library/LaunchAgents/<name>.plist
   ```

## Management

**Check if an agent is loaded:**
```bash
launchctl list | grep <agent-name>
```

**Unload an agent:**
```bash
launchctl unload ~/Library/LaunchAgents/<name>.plist
```

**Reload an agent:**
```bash
launchctl unload ~/Library/LaunchAgents/<name>.plist
launchctl load ~/Library/LaunchAgents/<name>.plist
```

## Current Agents

- `com.mknopf.kill-orphaned-claude.xml` - Periodically kills orphaned Claude processes that have been re-parented to launchd
