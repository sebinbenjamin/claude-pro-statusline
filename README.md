# claude-pro-statusline

A custom status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that displays model info, context window usage, token counts, and rate limit gauges — all color-coded at a glance.

```
Opus 4.6 (1M context) | ━━━━──────  40k/200k 40% | 12.3kin 5.1kout | 5h ██░░░░░░░░ 20% used ~4.2h (14:30) | 7d █░░░░░░░░░ 10% used ~6d
```

## What it shows

| Section | Description |
|---------|-------------|
| **Model** | Current model name |
| **Context window** | Bar + percentage of context used (green/yellow/red) |
| **Tokens** | Total input and output tokens for the session |
| **5h rate limit** | Fuel gauge for the 5-hour usage quota with reset countdown |
| **7d rate limit** | Fuel gauge for the 7-day usage quota with reset countdown |

## Requirements

- `bash`, `jq`, `awk`, `date` (standard on macOS/Linux; available on Windows via WSL or Git Bash)
- Claude Code CLI

## Installation

### Quick install

```bash
git clone https://github.com/sebinbenjamin/claude-pro-statusline.git
cd claude-pro-statusline
bash install.sh
```

### Manual install

1. Copy the script:

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Add this to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

> If the file already exists, merge the `statusLine` key into your existing config.

3. Restart Claude Code.

## Customizing — available JSON fields

The status line command receives a JSON object via stdin with all session data. Fork this script and use any of the fields below to build your own status line.

See the [official Claude Code status line docs](https://docs.anthropic.com/en/docs/claude-code/status-line) for full details and examples in Bash, Python, and Node.js.

<details>
<summary>Full JSON schema</summary>

```json
{
  "cwd": "/current/working/directory",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.jsonl",
  "version": "1.0.80",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus 4.6 (1M context)"
  },
  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory"
  },
  "output_style": {
    "name": "default"
  },
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour": {
      "used_percentage": 23.5,
      "resets_at": 1738425600
    },
    "seven_day": {
      "used_percentage": 41.2,
      "resets_at": 1738857600
    }
  },
  "vim": {
    "mode": "NORMAL"
  },
  "agent": {
    "name": "security-reviewer"
  },
  "worktree": {
    "name": "my-feature",
    "path": "/path/to/.claude/worktrees/my-feature",
    "branch": "worktree-my-feature",
    "original_cwd": "/path/to/project",
    "original_branch": "main"
  }
}
```

</details>

### Field highlights

| Field | Description |
|-------|-------------|
| `model.id` / `model.display_name` | Current model |
| `context_window.used_percentage` | How full the context window is |
| `context_window.context_window_size` | Max context (200k or 1M) |
| `cost.total_cost_usd` | Session cost in USD |
| `cost.total_duration_ms` | Total elapsed time |
| `cost.total_lines_added` / `total_lines_removed` | Code churn |
| `rate_limits.five_hour.*` / `seven_day.*` | Quota usage + reset epoch (Pro/Max only) |
| `vim.mode` | Vim mode, if enabled |
| `agent.name` | Agent name when using `--agent` |
| `worktree.*` | Worktree info during `--worktree` sessions |

> Some fields are conditional — `vim`, `agent`, `worktree`, and `rate_limits` may be absent depending on your setup and subscription.

## Uninstall

```bash
rm ~/.claude/statusline-command.sh
```

Then remove the `statusLine` key from `~/.claude/settings.json`.

## License

MIT
