#!/usr/bin/env bash
set -euo pipefail

# Claude Code Workflow — Installation Script
# Installs skills, commands, hooks, and global rules into ~/.claude/
# Safe to run multiple times (idempotent).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
COMMANDS_DIR="$CLAUDE_DIR/commands"
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
echo "  Created: $SKILLS_DIR"
echo "  Created: $COMMANDS_DIR"

# -------------------------------------------------------
# 2. Symlink skills
# -------------------------------------------------------
echo ""
echo "[2/6] Linking skills..."

# Remove stale symlinks for old skill names
for stale_skill in analyse plan build review orchestrate scope-guard root-cause-tracing verification receiving-feedback testing-anti-patterns; do
    stale_target="$SKILLS_DIR/$stale_skill"
    if [ -L "$stale_target" ]; then
        rm "$stale_target"
        echo "  Removed stale symlink: $stale_skill"
    fi
done

for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -d "$target" ]; then
        echo "  WARNING: $target exists as a real directory, skipping (remove manually to link)"
        continue
    fi
    ln -s "$skill_dir" "$target"
    echo "  Linked: $skill_name -> $skill_dir"
done

# -------------------------------------------------------
# 3. Symlink commands
# -------------------------------------------------------
echo ""
echo "[3/6] Linking commands..."

# Remove stale symlinks for old command filenames
for stale_cmd in analyse.md plan.md build.md review.md init.md status.md pipeline.md; do
    stale_target="$COMMANDS_DIR/$stale_cmd"
    if [ -L "$stale_target" ]; then
        rm "$stale_target"
        echo "  Removed stale symlink: $stale_cmd"
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
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -f "$target" ]; then
        echo "  WARNING: $target exists as a real file, skipping (remove manually to link)"
        continue
    fi
    ln -s "$cmd_file" "$target"
    echo "  Linked: $cmd_name -> $cmd_file"
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
# 5. Install hooks into ~/.claude/settings.json
# -------------------------------------------------------
echo ""
echo "[5/6] Installing hooks..."
HOOKS_SOURCE="$SCRIPT_DIR/hooks/hooks.json"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$HOOKS_SOURCE" ]; then
    if [ -f "$SETTINGS_FILE" ]; then
        # Check if hooks already exist in settings.json
        if grep -q '"hooks"' "$SETTINGS_FILE" 2>/dev/null; then
            echo "  WARNING: $SETTINGS_FILE already contains hooks configuration."
            echo "  Source:  $HOOKS_SOURCE"
            echo "  Review and merge manually if needed."
            echo "  (Skipping to avoid overwriting custom hooks)"
        else
            echo "  WARNING: $SETTINGS_FILE exists but has no hooks."
            echo "  You need to manually merge hooks from: $HOOKS_SOURCE"
            echo "  into: $SETTINGS_FILE"
        fi
    else
        # No settings.json — create with hooks content
        cp "$HOOKS_SOURCE" "$SETTINGS_FILE"
        echo "  Created: $SETTINGS_FILE"
    fi
else
    echo "  No hooks.json found in $SCRIPT_DIR/hooks/, skipping."
fi

# -------------------------------------------------------
# 6. Make hook scripts executable
# -------------------------------------------------------
echo ""
echo "[6/6] Setting permissions..."
hook_scripts_found=0
for hook_script in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/hooks/*.bash "$SCRIPT_DIR"/hooks/*.py; do
    if [ -f "$hook_script" ]; then
        chmod +x "$hook_script"
        echo "  Made executable: $(basename "$hook_script")"
        hook_scripts_found=1
    fi
done
if [ "$hook_scripts_found" -eq 0 ]; then
    echo "  No hook scripts found."
fi

# -------------------------------------------------------
# Done
# -------------------------------------------------------
echo ""
echo "=== Installation Complete ==="
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
echo "  Rules:    $GLOBAL_CLAUDE_MD"
echo "  Hooks:    $SETTINGS_FILE"
