#!/usr/bin/env bash
# Headless AI Second Brain - Skills Installer (macOS/Linux)
#
# Usage:  ./install.sh [AGENTS_SKILLS_DIR] [RULES_DIR] [BIN_DIR] [SCRIPTS_DIR] [HOOKS_DIR]
# Env vars: COPY=1 to copy instead of symlink; INSTALL_CLAUDE=1 / SKIP_CLAUDE=1 and
#           INSTALL_ANTIGRAVITY=1 / SKIP_ANTIGRAVITY=1 to bypass the auto-detect prompts.
set -e

AGENTS_SKILLS_DIR="${1:-$HOME/.agents/skills}"
RULES_DIR="${2:-$HOME/.agents/rules}"
BIN_DIR="${3:-$HOME/.agents/bin}"
SCRIPTS_DIR="${4:-$HOME/.agents/scripts}"
HOOKS_DIR="${5:-$HOME/.agents/hooks}"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
ANTIGRAVITY_SKILLS_DIR="$HOME/.gemini/config/skills"

echo "========================================"
echo "  Headless AI Second Brain - Skills Installer"
echo "========================================"

mkdir -p "$AGENTS_SKILLS_DIR"
mkdir -p "$RULES_DIR"
mkdir -p "$BIN_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_or_copy() {
  # link_or_copy <source> <dest> <skill-name> — the ONE place either target loop is allowed
  # to remove something at a skill destination. Refuses unless the existing item is confirmed
  # to be a symlink; a real directory is never provenance we can vouch for, so it's left alone.
  # (Plain `ln -sfn` already refuses to clobber a real directory without -f's help removing it
  # first — this makes that refusal explicit and applies the same rule in -Copy mode too,
  # where `rm -rf` would otherwise happily delete real content.)
  local src="$1" dest="$2" name="$3"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  [SKIP] $name -> $dest already exists as a REAL directory, not a link."
    echo "         Leaving it alone — remove it yourself first if you want this skill here."
    return 1
  fi
  if [ -n "$COPY" ]; then
    rm -rf "$dest"
    cp -r "$src" "$dest"
  else
    ln -sfn "$src" "$dest"
  fi
}

mirror_dir_is_already_aliased() {
  # True if $1 (a target skills dir as a whole) is itself a symlink — meaning every "skill"
  # found inside it is really $2's own content seen through the link. Iterating per-skill and
  # replacing each one would delete the one real copy on disk, one folder at a time — this is
  # exactly how a prior version of this script destroyed an entire personal skills library.
  [ -L "$1" ]
}

# --- Target 1: ~/.agents/skills — always installed. Repo's own neutral/base location,
# read directly by Codex and the emerging cross-tool SKILL.md convention. No detection needed.
echo ""
echo "[1/3] Installing to $AGENTS_SKILLS_DIR (Codex + open-standard tools)..."
find "$SCRIPT_DIR/skills" -name "SKILL.md" | while read -r skill_file; do
  skill_folder=$(dirname "$skill_file")
  skill_name=$(basename "$skill_folder")
  if link_or_copy "$skill_folder" "$AGENTS_SKILLS_DIR/$skill_name" "$skill_name"; then
    echo "  [LINK] $skill_name -> $skill_folder"
  fi
done

# --- Target 2: ~/.claude/skills — Claude Code's own directory (it does not read
# ~/.agents/skills natively). Only written if Claude appears installed, or the user opts in.
# Mirrors off $AGENTS_SKILLS_DIR (already installed above), not the repo — so there's exactly
# one real copy on disk, and ~/.claude/skills is just a pointer to it (same pattern as an
# existing personal ~/.agents/skills -> ~/.claude/skills setup).
echo ""
echo "[2/3] Checking for Claude Code / Claude Desktop..."
claude_detected=""
if [ -d "$HOME/.claude" ] || \
   [ -d "$HOME/Library/Application Support/Claude" ] || \
   command -v claude >/dev/null 2>&1; then
  claude_detected="1"
fi

install_claude=""
if [ -n "$SKIP_CLAUDE" ]; then
  echo "  SKIP_CLAUDE set; not touching ~/.claude/"
elif [ -n "$INSTALL_CLAUDE" ]; then
  install_claude="1"
elif [ -n "$claude_detected" ]; then
  echo "  Claude Code or Claude Desktop detected."
  install_claude="1"
elif [ -t 0 ]; then
  read -r -p "  Claude Code/Desktop not detected. Install skills there too, for later use? [y/N] " answer
  case "$answer" in
    [Yy]*) install_claude="1" ;;
  esac
else
  echo "  Claude not detected and not running interactively — skipping ~/.claude/skills."
  echo "  (Set INSTALL_CLAUDE=1 to force it, e.g. in a non-interactive install.)"
fi

if [ -n "$install_claude" ]; then
  if mirror_dir_is_already_aliased "$CLAUDE_SKILLS_DIR"; then
    echo "  $CLAUDE_SKILLS_DIR is already a symlink -> $(readlink "$CLAUDE_SKILLS_DIR")"
    echo "  It's already aliased to something as a whole directory. Nothing to mirror; not touching it."
  else
    mkdir -p "$CLAUDE_SKILLS_DIR"
    for skill_dir in "$AGENTS_SKILLS_DIR"/*; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      if link_or_copy "$skill_dir" "$CLAUDE_SKILLS_DIR/$skill_name" "$skill_name"; then
        echo "  [LINK] (claude) $skill_name -> $skill_dir"
      fi
    done
  fi
else
  echo "  Skipped — no ~/.claude/skills folder created."
fi

# --- Target 3: ~/.gemini/config/skills — Antigravity's global skills directory. Antigravity
# also reads a project-level <repo>/.agents/skills/ (walking up to the git root), out of scope
# for a machine-wide installer — same as Cursor's .cursor/skills/, documented below. Confirmed
# directly against Antigravity (2026-09) rather than assumed from docs.
echo ""
echo "[3/3] Checking for Antigravity IDE..."
antigravity_detected=""
if [ -d "$HOME/.gemini" ] || command -v antigravity >/dev/null 2>&1 || command -v gemini >/dev/null 2>&1; then
  antigravity_detected="1"
fi

install_antigravity=""
if [ -n "$SKIP_ANTIGRAVITY" ]; then
  echo "  SKIP_ANTIGRAVITY set; not touching ~/.gemini/"
elif [ -n "$INSTALL_ANTIGRAVITY" ]; then
  install_antigravity="1"
elif [ -n "$antigravity_detected" ]; then
  echo "  Antigravity (or the Gemini CLI) detected."
  install_antigravity="1"
elif [ -t 0 ]; then
  read -r -p "  Antigravity not detected. Install skills there too, for later use? [y/N] " answer
  case "$answer" in
    [Yy]*) install_antigravity="1" ;;
  esac
else
  echo "  Antigravity not detected and not running interactively — skipping ~/.gemini/config/skills."
  echo "  (Set INSTALL_ANTIGRAVITY=1 to force it, e.g. in a non-interactive install.)"
fi

if [ -n "$install_antigravity" ]; then
  if mirror_dir_is_already_aliased "$ANTIGRAVITY_SKILLS_DIR"; then
    echo "  $ANTIGRAVITY_SKILLS_DIR is already a symlink -> $(readlink "$ANTIGRAVITY_SKILLS_DIR")"
    echo "  It's already aliased to something as a whole directory. Nothing to mirror; not touching it."
  else
    mkdir -p "$ANTIGRAVITY_SKILLS_DIR"
    for skill_dir in "$AGENTS_SKILLS_DIR"/*; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      if link_or_copy "$skill_dir" "$ANTIGRAVITY_SKILLS_DIR/$skill_name" "$skill_name"; then
        echo "  [LINK] (antigravity) $skill_name -> $skill_dir"
      fi
    done
  fi
else
  echo "  Skipped — no ~/.gemini/config/skills folder created."
fi

# Link behavioral rules
if [ -d "$SCRIPT_DIR/rules" ]; then
  for rule in "$SCRIPT_DIR/rules"/*.md; do
    [ -f "$rule" ] || continue
    rule_name=$(basename "$rule")
    if link_or_copy "$rule" "$RULES_DIR/$rule_name" "$rule_name"; then
      echo "  [LINK] Rule:  $rule_name"
    fi
  done
fi

# Install git post-commit hook if in a git repository
if [ -d "$SCRIPT_DIR/.git/hooks" ] && [ -f "$SCRIPT_DIR/scripts/post-commit" ]; then
  cp "$SCRIPT_DIR/scripts/post-commit" "$SCRIPT_DIR/.git/hooks/post-commit"
  chmod +x "$SCRIPT_DIR/.git/hooks/post-commit" "$SCRIPT_DIR/scripts/obsidian-post-commit.sh" 2>/dev/null || true
  echo "  [HOOK] Installed post-commit hook to $SCRIPT_DIR/.git/hooks/post-commit"
fi

# Install CLI tools into BIN_DIR
if [ -d "$SCRIPT_DIR/bin" ]; then
  for bin_file in "$SCRIPT_DIR/bin"/*; do
    [ -f "$bin_file" ] || continue
    bin_name=$(basename "$bin_file")
    cp "$bin_file" "$BIN_DIR/$bin_name"
    chmod +x "$BIN_DIR/$bin_name" 2>/dev/null || true
    echo "  [CLI]  $bin_name -> $BIN_DIR/$bin_name"
  done
fi

# Install supporting scripts
if [ -d "$SCRIPT_DIR/scripts" ]; then
  mkdir -p "$SCRIPTS_DIR"
  for sf in "$SCRIPT_DIR/scripts"/*; do
    [ -f "$sf" ] || continue
    cp "$sf" "$SCRIPTS_DIR/$(basename "$sf")"
    echo "  [SCRIPT] $(basename "$sf") -> $SCRIPTS_DIR/$(basename "$sf")"
  done
fi

# Install Claude Code hook adapters — only alongside an actual Claude install, same reasoning
# as the skills target above (these hooks are meaningless without Claude Code).
if [ -n "$install_claude" ] && [ -d "$SCRIPT_DIR/hooks" ]; then
  mkdir -p "$HOOKS_DIR"
  for hk in "$SCRIPT_DIR/hooks"/*; do
    [ -f "$hk" ] || continue
    cp "$hk" "$HOOKS_DIR/$(basename "$hk")"
    echo "  [HOOK]  $(basename "$hk") -> $HOOKS_DIR/$(basename "$hk")"
  done
  echo "  NOTE: add cc-session-start.ps1 (SessionStart) and cc-post-bash.ps1 (PostToolUse:Bash)"
  echo "        to ~/.claude/settings.json as \"type\":\"command\" hooks to activate them."
fi

CONFIG_TARGET="$HOME/.agents/obsidian-config.json"
CONFIG_EXAMPLE="$SCRIPT_DIR/skills/obsidian-rag/obsidian-config.json.example"
if [ ! -f "$CONFIG_TARGET" ] && [ -f "$CONFIG_EXAMPLE" ]; then
  echo "  [CONFIG] Creating default config at $CONFIG_TARGET"
  cp "$CONFIG_EXAMPLE" "$CONFIG_TARGET"
fi

echo ""
echo "Done."
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "NOTE: To run 'obsidian-sync' directly, add $BIN_DIR to your PATH:"
  echo "  export PATH=\"\$PATH:$BIN_DIR\""
fi

echo ""
echo "Other agents:"
echo "  Cursor reads skills per-project from .cursor/skills/, not a global folder. Copy"
echo "  skills/obsidian-rag/* there manually in each project where you want them."
echo "  Antigravity ALSO reads a project-level <repo>/.agents/skills/, walking up to the git"
echo "  root — commit that folder in a project to share skills with a team there too."
echo "  ChatGPT (the chat product) doesn't scan a local folder — its Skills feature is"
echo "  upload-only and limited to Business/Enterprise/Edu accounts. .agents/skills is"
echo "  read by Codex, a different product. Use the pasted instructions block in"
echo "  connectors/chatgpt-desktop/form-instructions.md instead."

echo ""
echo "Next Step:"
echo "  Run '/obsidian-setup' in chat to configure your vault, or customize '$CONFIG_TARGET'"
echo ""
