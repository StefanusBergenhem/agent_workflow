#!/usr/bin/env bash
set -euo pipefail

# Claude Code Workflow — Installation Script
# Copies skills, commands, hooks, and global rules into ~/.claude/
# Safe to run multiple times (idempotent).
#
# All artifacts are copied (not symlinked) so ~/.claude/ is fully
# self-contained — no runtime dependency on this repo. This matters
# for Docker containers that mount ~/.claude/ but not this repo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
HOOKS_DIR="$CLAUDE_DIR/hooks"
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARKER="# --- Claude Code Workflow (managed block) ---"

echo "=== Claude Code Workflow Installer ==="
echo ""

# -------------------------------------------------------
# 1. Create ~/.claude directories
# -------------------------------------------------------
echo "[1/6] Creating directories..."
mkdir -p "$SKILLS_DIR"
mkdir -p "$COMMANDS_DIR"
mkdir -p "$HOOKS_DIR"
echo "  Created: $SKILLS_DIR"
echo "  Created: $COMMANDS_DIR"
echo "  Created: $HOOKS_DIR"

# -------------------------------------------------------
# 2. Copy skills
# -------------------------------------------------------
echo ""
echo "[2/6] Copying skills..."

# Remove stale entries for old skill names
for stale_skill in analyse plan build review orchestrate scope-guard root-cause-tracing verification receiving-feedback testing-anti-patterns; do
    stale_target="$SKILLS_DIR/$stale_skill"
    if [ -L "$stale_target" ] || [ -d "$stale_target" ]; then
        rm -rf "$stale_target"
        echo "  Removed stale: $stale_skill"
    fi
done

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"
    # Remove previous version (symlink or directory)
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        rm -rf "$target"
    fi
    cp -r "$skill_dir" "$target"
    echo "  Copied: $skill_name"
done

# -------------------------------------------------------
# 3. Copy commands
# -------------------------------------------------------
echo ""
echo "[3/6] Copying commands..."

# Remove stale entries for old command filenames
for stale_cmd in analyse.md plan.md build.md review.md init.md status.md pipeline.md; do
    stale_target="$COMMANDS_DIR/$stale_cmd"
    if [ -L "$stale_target" ] || [ -f "$stale_target" ]; then
        rm -f "$stale_target"
        echo "  Removed stale: $stale_cmd"
    fi
done

for cmd_file in "$SCRIPT_DIR"/commands/*.md; do
    cmd_name="$(basename "$cmd_file")"
    # Skip legacy project-specific commands (proj-*.md)
    if [[ "$cmd_name" == proj-* ]]; then
        echo "  Skipped (legacy): $cmd_name"
        continue
    fi
    target="$COMMANDS_DIR/$cmd_name"
    # Remove previous version (symlink or file)
    if [ -L "$target" ]; then
        rm "$target"
    fi
    cp "$cmd_file" "$target"
    echo "  Copied: $cmd_name"
done

# -------------------------------------------------------
# 4. Append global-claude.md to ~/.claude/CLAUDE.md
# -------------------------------------------------------
echo ""
echo "[4/6] Updating global CLAUDE.md..."
if [ ! -f "$GLOBAL_CLAUDE_MD" ]; then
    # No existing CLAUDE.md — create with marker and content
    {
        echo "$MARKER"
        echo ""
        cat "$SCRIPT_DIR/global-claude.md"
        echo ""
        echo "$MARKER END"
    } > "$GLOBAL_CLAUDE_MD"
    echo "  Created: $GLOBAL_CLAUDE_MD"
elif grep -qF "$MARKER" "$GLOBAL_CLAUDE_MD"; then
    # Marker exists — replace the managed block
    # Use awk to replace content between markers
    awk -v marker="$MARKER" -v content_file="$SCRIPT_DIR/global-claude.md" '
        BEGIN { in_block=0; replaced=0 }
        $0 == marker" END" { in_block=0; next }
        $0 == marker {
            if (!replaced) {
                print marker
                print ""
                while ((getline line < content_file) > 0) print line
                print ""
                print marker" END"
                replaced=1
            }
            in_block=1
            next
        }
        !in_block { print }
    ' "$GLOBAL_CLAUDE_MD" > "$GLOBAL_CLAUDE_MD.tmp"
    mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"
    echo "  Updated managed block in: $GLOBAL_CLAUDE_MD"
else
    # No marker — append with marker
    {
        echo ""
        echo "$MARKER"
        echo ""
        cat "$SCRIPT_DIR/global-claude.md"
        echo ""
        echo "$MARKER END"
    } >> "$GLOBAL_CLAUDE_MD"
    echo "  Appended to: $GLOBAL_CLAUDE_MD"
fi

# -------------------------------------------------------
# 5. Copy hooks and install into settings.json
# -------------------------------------------------------
echo ""
echo "[5/6] Installing hooks..."
HOOKS_SOURCE="$SCRIPT_DIR/hooks/hooks.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Copy hook scripts to ~/.claude/hooks/
hook_scripts_found=0
for hook_script in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/hooks/*.bash "$SCRIPT_DIR"/hooks/*.py; do
    if [ -f "$hook_script" ]; then
        cp "$hook_script" "$HOOKS_DIR/"
        chmod +x "$HOOKS_DIR/$(basename "$hook_script")"
        echo "  Copied: $(basename "$hook_script") -> $HOOKS_DIR/"
        hook_scripts_found=1
    fi
done
if [ "$hook_scripts_found" -eq 0 ]; then
    echo "  No hook scripts found."
fi

# Install hook config into settings.json with absolute paths to ~/.claude/hooks/
if [ -f "$HOOKS_SOURCE" ]; then
    # Rewrite relative paths to absolute ~/.claude/hooks/ paths
    HOOKS_JSON=$(sed "s|hooks/|$HOOKS_DIR/|g" "$HOOKS_SOURCE")

    if [ -f "$SETTINGS_FILE" ]; then
        # Merge hooks into existing settings.json
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
settings = json.load(open('$SETTINGS_FILE'))
hooks = json.loads('''$HOOKS_JSON''')
settings['hooks'] = hooks['hooks']
json.dump(settings, open('$SETTINGS_FILE', 'w'), indent=2)
print('  Merged hooks into: $SETTINGS_FILE')
"
        else
            echo "  WARNING: python3 not found. Cannot merge hooks automatically."
            echo "  Manually merge hooks from: $HOOKS_SOURCE"
            echo "  into: $SETTINGS_FILE"
            echo "  NOTE: Use absolute paths (prefix with $HOOKS_DIR/)"
        fi
    else
        # No settings.json — create with hooks content (absolute paths)
        echo "$HOOKS_JSON" > "$SETTINGS_FILE"
        echo "  Created: $SETTINGS_FILE"
    fi
else
    echo "  No hooks.json found, skipping config."
fi

# -------------------------------------------------------
# 6. Summary
# -------------------------------------------------------
echo ""
echo "=== Installation Complete ==="
echo ""
echo "All artifacts copied to ~/.claude/ (no symlinks, fully self-contained)."
echo ""
echo "Next steps:"
echo "  1. Review ~/.claude/CLAUDE.md to confirm global rules"
echo "  2. In your project, run /wf-command-init to bootstrap .workflow/"
echo "     (or /wf-command-init deep for existing codebases)"
echo "  3. Run /wf-command-strategist to create a product roadmap"
echo "  4. Run /wf-command-sa to define components and master backlog"
echo "  5. Run /wf-command-swa to detail the first sprint"
echo "  6. Run /wf-command-pipeline to execute the sprint"
echo ""
echo "Installed components:"
echo "  Skills:   $SKILLS_DIR/"
echo "  Commands: $COMMANDS_DIR/"
echo "  Hooks:    $HOOKS_DIR/"
echo "  Rules:    $GLOBAL_CLAUDE_MD"
echo "  Config:   $SETTINGS_FILE"
echo "  Templates: $SCRIPT_DIR/templates/ (reference only, not copied)"
