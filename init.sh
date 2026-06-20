#!/usr/bin/env bash
#
# pi-superpowers-init.sh
#
# Quick install (run on a fresh machine):
#   bash <(curl -fsSL https://raw.githubusercontent.com/guru-irl/pi-init/main/init.sh)
#
# One-shot setup for a new machine:
#   - Node (system package manager, only if missing) + pi (global npm install)
#   - pi packages: pi-subagents, context-mode, pi-todo-sqlite (durable per-project todos)
#   - pi-ctx-ui local extension (nicer ctx_* tool UI)
#   - context-mode MCP server (global) for any agent
#   - custom superpowers skills (guru-irl/superpowers) for pi / Claude Code / Copilot CLI
#   - GitHub CLI auth (for the Copilot license account)
#   - GitHub Copilot CLI + context-mode wiring (optional)
#   - pi global bootstrap prompt (~/.pi/agent/AGENTS.md)
#
# Usage:
#   bash <(curl -fsSL <raw-url>)                   # one-liner, interactive auth (recommended)
#   bash pi-superpowers-init.sh                     # from a local copy
#   GH_TOKEN=ghp_xxx bash pi-superpowers-init.sh    # non-interactive gh auth
#   SKIP_COPILOT_CLI=1 bash pi-superpowers-init.sh  # skip GitHub Copilot CLI install
#
set -euo pipefail

SUPERPOWERS_REPO="${SUPERPOWERS_REPO:-https://github.com/guru-irl/superpowers.git}"
SUPERPOWERS_DIR="${SUPERPOWERS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/guru-superpowers}"
PI_PACKAGES=("npm:pi-subagents" "npm:context-mode" "git:github.com/guru-irl/pi-todo-sqlite")
SKILL_DESTS=("$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.copilot/skills")

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
ensure_node() {
  local need=22  # pi-todo-sqlite uses node:sqlite (needs Node >= 22.5)
  if have node && have npm; then
    local major; major="$(node -v | sed 's/^v//; s/\..*//')"
    if [ "${major:-0}" -ge "$need" ]; then log "node present: $(node -v)"; return; fi
    warn "node $(node -v) is older than v${need} (node:sqlite needs >= v22.5); installing a newer Node"
  else
    log "Node/npm not found; installing Node >= v${need} the regular way (system package manager)..."
  fi
  if have brew; then brew install node
  elif have apt-get; then curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs
  elif have dnf; then curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo -E bash - && sudo dnf install -y nodejs
  elif have pacman; then sudo pacman -Sy --noconfirm nodejs npm
  elif have zypper; then sudo zypper install -y nodejs22 || sudo zypper install -y nodejs
  elif have apk; then sudo apk add --no-cache nodejs npm
  else warn "No supported package manager found. Install Node >= v${need} from https://nodejs.org and re-run."; exit 1
  fi
  have node && have npm || { warn "Node/npm still not on PATH after install."; exit 1; }
  log "node now: $(node -v) (npm $(npm -v))"
}

ensure_pi() {
  if have pi; then log "pi present: $(pi --version 2>/dev/null | head -1)"; return; fi
  log "Installing pi globally via npm (npm install -g @earendil-works/pi-coding-agent)..."
  if ! npm install -g --ignore-scripts @earendil-works/pi-coding-agent; then
    warn "Global install failed (likely npm prefix permissions); retrying with sudo..."
    sudo npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  fi
  have pi || warn "pi installed but not on PATH; add \"\$(npm prefix -g)/bin\" to your PATH."
}

ensure_gh_and_auth() {
  if ! have gh; then
    warn "GitHub CLI (gh) not found. Install it from https://cli.github.com/ then re-run for auth."
    return
  fi
  if gh auth status >/dev/null 2>&1; then log "gh already authenticated."; return; fi
  log "Authenticating GitHub CLI (for your Copilot license account)..."
  if [ -n "${GH_TOKEN:-}" ]; then
    printf '%s' "$GH_TOKEN" | gh auth login --hostname github.com --git-protocol https --with-token
  else
    gh auth login --hostname github.com --git-protocol https --web || \
      warn "gh auth not completed; re-run 'gh auth login' later."
  fi
  gh auth setup-git 2>/dev/null || true
}

ensure_context_mode_global() {
  if have context-mode; then log "context-mode present globally."; return; fi
  log "Installing context-mode globally..."
  npm install -g context-mode
}

ensure_copilot_cli() {
  [ "${SKIP_COPILOT_CLI:-0}" = "1" ] && { log "Skipping GitHub Copilot CLI."; return; }
  if have copilot; then log "GitHub Copilot CLI present."; return; fi
  log "Installing GitHub Copilot CLI (@github/copilot)..."
  npm install -g @github/copilot || warn "Copilot CLI install failed; skipping."
}

install_superpowers() {
  log "Fetching custom superpowers from $SUPERPOWERS_REPO ..."
  if [ -d "$SUPERPOWERS_DIR/.git" ]; then
    git -C "$SUPERPOWERS_DIR" pull --ff-only || warn "could not fast-forward superpowers clone"
  else
    mkdir -p "$(dirname "$SUPERPOWERS_DIR")"
    git clone --depth 1 "$SUPERPOWERS_REPO" "$SUPERPOWERS_DIR"
  fi
  local src="$SUPERPOWERS_DIR/skills"
  [ -d "$src" ] || { warn "no skills/ dir in superpowers repo"; return; }
  for dest in "${SKILL_DESTS[@]}"; do
    mkdir -p "$dest"
    for skill in "$src"/*/; do
      [ -d "$skill" ] || continue
      local name; name="$(basename "$skill")"
      rm -rf "${dest:?}/$name"
      cp -r "$skill" "$dest/$name"
    done
    log "Installed $(ls "$src" | wc -l) superpowers skills -> $dest"
  done
}

configure_pi() {
  local agent_dir="$HOME/.pi/agent"; mkdir -p "$agent_dir/skills"
  log "Installing pi packages..."
  if have pi; then
    for pkg in "${PI_PACKAGES[@]}"; do pi install "$pkg" || warn "pi install $pkg failed"; done
  else
    warn "pi not on PATH; ensure packages later with: pi install <pkg>"
  fi
  log "Writing pi global bootstrap prompt -> $agent_dir/AGENTS.md"
  [ -f "$agent_dir/AGENTS.md" ] && cp "$agent_dir/AGENTS.md" "$agent_dir/AGENTS.md.bak"
  cat > "$agent_dir/AGENTS.md" <<'AGENTS_EOF'
# Agent operating guide (global)

This machine is set up with a specific toolset. Use it. When a capability below
applies, prefer it over ad-hoc approaches.

**Before acting on any non-trivial request — reflexively, before your first tool
call:** (1) load and follow `using-superpowers` (read its `SKILL.md`) plus any
other applicable skill, and (2) default verbose shell/file work to the
context-mode `ctx_*` tools (see Token performance). These are the baseline
workflow on this machine, not optional add-ons.

## Skills (superpowers) — invoke before acting

A superpowers skill library is installed. **At the start of any non-trivial task,
load and follow `using-superpowers`** (read its `SKILL.md`), then any other skill
that applies (brainstorming, writing-plans, test-driven-development,
systematic-debugging, subagent-driven-development, requesting-code-review,
finishing-a-development-branch, etc.). If there's even a 1% chance a skill
applies, check it. User instructions always take precedence over skills.

Skills live in `~/.agents/skills/` and `~/.pi/agent/skills/`. Load a skill by
reading its `SKILL.md` (resolve a skill's relative paths against its own dir).

## Delegation — `subagent` (pi-subagents)

For recon, parallel work, review, and implementation handoffs, delegate with the
`subagent(...)` tool. Builtin roles: `worker` (implement), `reviewer` (review,
use `context: "fresh"`), `scout` (recon), `planner`, `context-builder`,
`researcher`, `oracle`, `delegate`. Keep a single writer at a time; give
review-only children fresh context and tell them not to edit source. Pass
per-call `model:` to match task complexity (cheap for mechanical, capable for
architecture/review), and `skill:` to make a child follow an execution skill
(e.g. `skill: "test-driven-development"`). Prefer `async: true` for long runs.

## Token performance — context-mode (`ctx_*`)

context-mode routing is always on (it blocks raw HTTP-flooding commands). Routing
**everything else is your job**: prefer `ctx_*` over raw read/bash whenever output
could be large — the bytes stay sandboxed and only what you print/query enters
context.

**Default rule: if a command could print more than ~10 lines, run it through
`ctx_execute` (several related commands → `ctx_batch_execute`) and print only what
you need.** This explicitly includes, and is not limited to:
- `git` (log, diff, status, show, blame), `gh` (issue/pr/run list & view, `api`),
  and `az` CLI — these routinely exceed 10 lines, so default them to `ctx_execute`.
- `kubectl`, `docker`, `npm`/`pnpm`/`yarn`, dependency/audit queries, and any
  repo-wide `grep`/`find`/`ls -R`.
- Test runs, builds, and logs → `ctx_execute` / `ctx_batch_execute` (add an
  `intent` so large output is indexed and you get back only the relevant slice).
- Analyze/summarize a large file you won't edit → `ctx_execute_file` (use plain
  `read` when you will edit, so edits match exact text).
- Web docs → `ctx_fetch_and_index` then `ctx_search`.
- Repeatedly referenced plan/spec/docs → `ctx_index` once, then `ctx_search`.

Use plain `bash` only for short commands (≪10 lines) whose full output you want
verbatim — e.g. `whoami`, `pwd`, a one-line `git rev-parse`, `gh auth status`.

## Task tracking — `todo` (durable, SQLite-backed)

Use the `todo` tool (`add`, `toggle`, `list`, `clear`) to track multi-step work.
Todos persist per-project across sessions and mirror into context-mode (so
`ctx_search` can surface them). Add one todo per checklist item and toggle as you
complete each; view them anytime with the `/todos` command.
AGENTS_EOF
}

configure_copilot_cli() {
  local cdir="$HOME/.copilot"
  have copilot || [ -d "$cdir" ] || { log "Copilot CLI not present; skipping its wiring."; return; }
  mkdir -p "$cdir"
  # 1) Merge context-mode into Copilot CLI MCP config (non-destructive).
  local mcp="$cdir/mcp-config.json"
  [ -f "$mcp" ] && cp "$mcp" "$mcp.bak"
  python3 - "$mcp" <<'PY'
import json,sys,os
p=sys.argv[1]
d={}
if os.path.exists(p):
    try: d=json.load(open(p))
    except Exception: d={}
d.setdefault("mcpServers",{})
d["mcpServers"]["context-mode"]={"type":"local","command":"context-mode","tools":["*"]}
json.dump(d,open(p,"w"),indent=2)
print("context-mode wired into",p)
PY
  # 2) Idempotent managed instructions block in the confirmed global personal file.
  local instr="$cdir/copilot-instructions.md"; local tmp; tmp="$(mktemp)"
  cat > "$tmp" <<'COPILOT_EOF'
# context-mode — token-performance routing

The `context-mode` MCP server is configured for this CLI (`ctx_*` tools). Prefer
it over reading raw data into context: the bytes stay in a sandbox and only what
you print or query returns. This keeps large outputs from flooding the context
window. These are strong preferences, not hard blocks.

## Think in code

To analyze / count / filter / compare / search / parse / transform data, write a
small script via `ctx_execute(language, code)` and `console.log()` only the
answer — do not read the raw data into context. One script replaces many tool
calls. Use Node.js built-ins (`fs`, `path`, `child_process`); guard with
try/catch and handle null/undefined.

## Routing preferences

- **Large command output** (`git diff`, test runs, logs, repo-wide greps):
  prefer `ctx_execute(language: "shell", code: "...")` or, for several related
  commands, `ctx_batch_execute(commands, queries)` — one call replaces many.
- **Analyze/summarize a large file** (not editing it): prefer
  `ctx_execute_file(path, language, code)`. If you are going to edit the file,
  read it normally so edits match exact text.
- **Web pages / docs**: prefer `ctx_fetch_and_index(url, source)` then
  `ctx_search(queries)` — raw HTML never enters context.
- **Repeatedly referenced docs/specs/plans**: `ctx_index(content|path, source)`
  once, then `ctx_search(queries)` instead of re-reading.
- **Plain reads/edits, small outputs, navigation** (`ls`, `cd`, `git status`,
  editing a file): use normal tools — context-mode is only for large or derived
  output.

## Memory

context-mode session memory is persistent and searchable. On resume, search
before asking the user what you were doing:

- "what were we working on?" → `ctx_search(queries: ["summary"], source: "compaction", sort: "timeline")`
- "what did we decide?" → `ctx_search(queries: ["decision"], source: "decision", sort: "timeline")`

If search returns nothing, proceed as a fresh session.

## ctx commands

- `ctx stats` → call `ctx_stats`, show output verbatim
- `ctx doctor` → call `ctx_doctor`, run the returned command, show as a checklist
- `ctx purge` → call `ctx_purge` with `confirm: true` (wipes the knowledge base)
COPILOT_EOF
  python3 - "$instr" "$tmp" <<'PY'
import sys,os
instr,block_path=sys.argv[1],sys.argv[2]
BEGIN="<!-- BEGIN context-mode (managed) -->"; END="<!-- END context-mode (managed) -->"
block=open(block_path).read().rstrip("\n")
existing=open(instr).read() if os.path.exists(instr) else ""
managed=f"{BEGIN}\n{block}\n{END}\n"
if BEGIN in existing and END in existing:
    out=existing.split(BEGIN)[0]+managed+existing.split(END,1)[1]
else:
    out=(existing.rstrip()+"\n\n" if existing.strip() else "")+managed
open(instr,"w").write(out)
print("updated",instr)
PY
  rm -f "$tmp"
  log "Copilot CLI: context-mode MCP + instructions configured."
}

install_ctx_ui() {
  # pi-ctx-ui gives context-mode's ctx_* tools a nicer per-command call/result UI.
  # It MUST be a local (auto-discovered) extension: as a pi package it would load
  # with package precedence and silently fail to override context-mode's tools.
  local dir="$HOME/.pi/agent/extensions/pi-ctx-ui"
  local repo="https://github.com/guru-irl/pi-ctx-ui"
  if [ -d "$dir/.git" ]; then
    log "Updating pi-ctx-ui (ctx_* tool UI) in $dir"
    git -C "$dir" pull --ff-only -q || warn "pi-ctx-ui pull failed; keeping existing copy"
  else
    log "Installing pi-ctx-ui (nicer ctx_* tool UI) -> $dir"
    rm -rf "$dir"
    git clone -q "$repo" "$dir" || warn "pi-ctx-ui clone failed; context-mode's own ctx UI remains"
  fi
}

main() {
  ensure_node
  ensure_pi
  ensure_gh_and_auth
  ensure_context_mode_global
  ensure_copilot_cli
  install_superpowers
  configure_pi
  install_ctx_ui
  configure_copilot_cli
  cat <<EOF

\033[1;32mDone.\033[0m Next steps:
  - Launch 'pi' and run /login -> GitHub Copilot (device flow) if not already authed.
  - For GitHub Copilot CLI, run 'copilot' once to complete its GitHub login.
  - superpowers skills, context-mode (ctx_*), pi-subagents, pi-todo-sqlite installed.
  - pi-ctx-ui local extension installed (nicer ctx_* tool UI; run /reload to refresh).
EOF
}
main "$@"
