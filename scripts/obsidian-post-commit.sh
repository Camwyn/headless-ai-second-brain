#!/usr/bin/env sh
# Camwyn Agent Skills - Git Post-Commit Sync Hook (POSIX Shell)
# Autonomously queues git milestones to .agents/pending-sync.json for Obsidian live-sync

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_ROOT" ] && exit 0
PROJECT_NAME="$(basename "$REPO_ROOT")"

# Locate config
CONFIG_FILE="$REPO_ROOT/.agents/obsidian-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.agents/obsidian-config.json"
fi
[ ! -f "$CONFIG_FILE" ] && exit 0

# Map repo folder name -> canonical vault project folder (config: project_aliases).
# Use when the repo folder name differs from the vault project name (nested repos,
# monorepo subprojects, or a renamed repo) so commits don't spawn a divergent folder.
if command -v jq >/dev/null 2>&1; then
    ALIASED="$(jq -r --arg p "$PROJECT_NAME" '.project_aliases[$p] // empty' "$CONFIG_FILE" 2>/dev/null)"
    [ -n "$ALIASED" ] && PROJECT_NAME="$ALIASED"
fi

# Check commit info
COMMIT_HASH="$(git rev-parse --short HEAD 2>/dev/null)"
COMMIT_SUBJECT="$(git log -1 --format="%s" 2>/dev/null)"
AUTHOR="$(git log -1 --format="%an" 2>/dev/null)"
COMMIT_DATE="$(git log -1 --format="%aI" 2>/dev/null)"

[ -z "$COMMIT_HASH" ] && exit 0

# Significance check
case "$COMMIT_SUBJECT" in
    feat*|refactor*|breaking*|perf*|*"BREAKING CHANGE"*)
        ;;
    *)
        exit 0
        ;;
esac

QUEUE_DIR="$REPO_ROOT/.agents"
mkdir -p "$QUEUE_DIR"
QUEUE_FILE="$QUEUE_DIR/pending-sync.json"

if command -v jq >/dev/null 2>&1; then
    # Read or initialize
    [ -f "$QUEUE_FILE" ] || echo "[]" > "$QUEUE_FILE"
    
    # Avoid duplicate
    if jq -e ".[] | select(.commit.hash == \"$COMMIT_HASH\")" "$QUEUE_FILE" >/dev/null 2>&1; then
        exit 0
    fi

    VAULT="$(jq -r '.default_vault // "default"' "$CONFIG_FILE" 2>/dev/null)"
    PROJECTS_DIR="$(jq -r '.para.projects_dir // .projects_dir // "Projects"' "$CONFIG_FILE" 2>/dev/null)"

    NEW_ENTRY=$(jq -n \
        --arg id "commit-$COMMIT_HASH" \
        --arg ts "$COMMIT_DATE" \
        --arg type "commit" \
        --arg vault "$VAULT" \
        --arg target "$PROJECTS_DIR/$PROJECT_NAME/Worklog.md" \
        --arg proj "$PROJECT_NAME" \
        --arg hash "$COMMIT_HASH" \
        --arg sub "$COMMIT_SUBJECT" \
        --arg auth "$AUTHOR" \
        --arg date "$COMMIT_DATE" \
        '{
            id: $id,
            timestamp: $ts,
            type: $type,
            vault: $vault,
            target_path: $target,
            project: $proj,
            commit: {
                hash: $hash,
                subject: $sub,
                author: $auth,
                date: $date
            },
            source: "git-post-commit-hook"
        }')

    jq ". += [$NEW_ENTRY]" "$QUEUE_FILE" > "${QUEUE_FILE}.tmp" && mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"
    echo "[obsidian-sync] Queued milestone [$COMMIT_HASH] to .agents/pending-sync.json"
fi

exit 0
