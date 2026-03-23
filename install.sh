#!/usr/bin/env bash
set -e

DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

echo "Installing claude-pro-statusline..."

# Copy script
cp statusline-command.sh "$DEST"
chmod +x "$DEST"
echo "  Installed $DEST"

# Update settings.json
STATUS_CFG='{"type":"command","command":"~/.claude/statusline-command.sh"}'

if [ -f "$SETTINGS" ]; then
  if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --argjson sl "$STATUS_CFG" '.statusLine = $sl' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "  Updated $SETTINGS (existing file, merged statusLine)"
  else
    echo "  WARNING: jq not found. Please manually add the statusLine config to $SETTINGS"
    echo "  (see README for the JSON snippet)"
  fi
else
  mkdir -p "$(dirname "$SETTINGS")"
  cat > "$SETTINGS" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
EOF
  echo "  Created $SETTINGS"
fi

echo "Done! Restart Claude Code to see the status line."
