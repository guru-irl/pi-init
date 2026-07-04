#!/usr/bin/env bash
#
# pi-init — spider-first bootstrap for a fresh machine.
#
# Quick install (run on a fresh machine):
#   bash <(curl -fsSL https://raw.githubusercontent.com/guru-irl/pi-init/main/init.sh)
#
# One-shot setup for a new machine:
#   - Node (system package manager, only if missing) + pi (global npm install)
#   - spider (github.com/guru-irl/spider): the ONE unified pi extension — subagents,
#     memory, unified search, todos, sandboxed exec, web fetch — on a shared SQLite DB.
#     Replaces pi-subagents, context-mode (ctx_*), and pi-todo-sqlite.
#   - companion pi packages: pi-intercom, pi-prompt-template-model
#   - custom superpowers skills (guru-irl/superpowers) for pi / Claude Code / Copilot CLI
#   - GitHub CLI auth (for the Copilot license account) + optional GitHub Copilot CLI
#   - spider-managed global bootstrap prompt (~/.pi/agent/AGENTS.md)
#
# Usage:
#   bash <(curl -fsSL <raw-url>)                   # one-liner, interactive auth (recommended)
#   bash init.sh                                    # from a local copy
#   GH_TOKEN=ghp_xxx bash init.sh                   # non-interactive gh auth
#   SKIP_COPILOT_CLI=1 bash init.sh                 # skip GitHub Copilot CLI install
#
set -euo pipefail

SUPERPOWERS_REPO="${SUPERPOWERS_REPO:-https://github.com/guru-irl/superpowers.git}"
SUPERPOWERS_DIR="${SUPERPOWERS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/guru-superpowers}"
SPIDER_REPO="${SPIDER_REPO:-https://github.com/guru-irl/spider.git}"
SPIDER_DIR="${SPIDER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/spider}"
# Companion pi packages (spider replaces subagents/context-mode/todo, so those are NOT here).
PI_PACKAGES=("npm:pi-intercom" "npm:pi-prompt-template-model")
# Legacy packages spider supersedes — removed from ~/.pi/agent/settings.json on (re)run.
LEGACY_PACKAGES=("npm:pi-subagents" "npm:context-mode" "git:github.com/guru-irl/pi-todo-sqlite")
SKILL_DESTS=("$HOME/.agents/skills" "$HOME/.claude/skills" "$HOME/.copilot/skills")

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
ensure_node() {
  local need=24  # spider pins node 24 (volta); native better-sqlite3 must match pi's ABI 137
  if have node && have npm; then
    local major; major="$(node -v | sed 's/^v//; s/\..*//')"
    if [ "${major:-0}" -ge "$need" ]; then log "node present: $(node -v)"; return; fi
    warn "node $(node -v) is older than v${need} (spider builds under node ${need}); installing a newer Node"
  else
    log "Node/npm not found; installing Node >= v${need} the regular way (system package manager)..."
  fi
  if have brew; then brew install node
  elif have apt-get; then curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt-get install -y nodejs
  elif have dnf; then curl -fsSL https://rpm.nodesource.com/setup_24.x | sudo -E bash - && sudo dnf install -y nodejs
  elif have pacman; then sudo pacman -Sy --noconfirm nodejs npm
  elif have zypper; then sudo zypper install -y nodejs24 || sudo zypper install -y nodejs
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

ensure_copilot_cli() {
  [ "${SKIP_COPILOT_CLI:-0}" = "1" ] && { log "Skipping GitHub Copilot CLI."; return; }
  if have copilot; then log "GitHub Copilot CLI present."; return; fi
  log "Installing GitHub Copilot CLI (@github/copilot)..."
  npm install -g @github/copilot || warn "Copilot CLI install failed; skipping."
}

# Clone/build/dev-link spider, then write its managed AGENTS.md block.
ensure_spider() {
  log "Installing spider (unified pi extension) from $SPIDER_REPO ..."
  if [ -d "$SPIDER_DIR/.git" ]; then
    git -C "$SPIDER_DIR" pull --ff-only || warn "could not fast-forward spider clone"
  else
    mkdir -p "$(dirname "$SPIDER_DIR")"
    git clone "$SPIDER_REPO" "$SPIDER_DIR"
  fi
  (
    cd "$SPIDER_DIR"
    log "Building spider (npm install + build; native better-sqlite3/sqlite-vec)..."
    npm install || { warn "spider npm install failed — fix and re-run"; return 1; }
    npm run build || { warn "spider build failed — fix and re-run"; return 1; }
    log "Linking spider into pi (stable shim → ~/.pi/agent/extensions/spider.ts)..."
    npm run link || warn "spider link failed; link manually with 'npm run link'"
    log "Writing spider-managed AGENTS.md (~/.pi/agent/AGENTS.md)..."
    [ -f "$HOME/.pi/agent/AGENTS.md" ] && cp "$HOME/.pi/agent/AGENTS.md" "$HOME/.pi/agent/AGENTS.md.bak"
    npx --yes tsx -e 'import("./packages/superpowers/src/agentsmd.ts").then(async (m) => { const os = await import("node:os"); const p = os.homedir() + "/.pi/agent/AGENTS.md"; console.log("AGENTS.md:", m.writeAgentsMd(p).action); }).catch((e) => { console.error(String(e)); process.exit(1); })' \
      || warn "AGENTS.md write failed; spider will write it on first pi load"
  ) || warn "spider setup incomplete — see warnings above"
}

# Remove the packages spider supersedes from pi's load list (idempotent migration).
cleanup_legacy_packages() {
  local settings="$HOME/.pi/agent/settings.json"
  [ -f "$settings" ] || return 0
  log "Removing legacy packages spider replaces from $settings ..."
  cp "$settings" "$settings.bak"
  LEGACY="${LEGACY_PACKAGES[*]}" node -e '
    const fs = require("fs");
    const p = process.argv[1];
    const legacy = new Set((process.env.LEGACY || "").split(" ").filter(Boolean));
    const cfg = JSON.parse(fs.readFileSync(p, "utf8"));
    if (Array.isArray(cfg.packages)) {
      const before = cfg.packages.length;
      cfg.packages = cfg.packages.filter((x) => !legacy.has(x));
      fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
      console.log(`packages: ${before} → ${cfg.packages.length}`);
    }
  ' "$settings" || warn "could not prune legacy packages from settings.json"
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
  log "Installing companion pi packages (pi-intercom, pi-prompt-template-model)..."
  if have pi; then
    for pkg in "${PI_PACKAGES[@]}"; do pi install "$pkg" || warn "pi install $pkg failed"; done
  else
    warn "pi not on PATH; ensure packages later with: pi install <pkg>"
  fi
  cleanup_legacy_packages
  # NOTE: AGENTS.md is spider-managed (written by ensure_spider and re-upserted by spider on
  # every load); pi-init no longer hardcodes it, so the guide never drifts from the extension.
}

main() {
  ensure_node
  ensure_pi
  ensure_gh_and_auth
  ensure_copilot_cli
  install_superpowers
  ensure_spider
  configure_pi
  cat <<EOF

\033[1;32mDone.\033[0m Next steps:
  - Launch 'pi' and run /login -> GitHub Copilot (device flow) if not already authed.
  - For GitHub Copilot CLI, run 'copilot' once to complete its GitHub login.
  - spider (subagents + memory + search + todos + exec + fetch) is linked; run /reload
    or relaunch pi to load it. Old pi-subagents / context-mode / pi-todo-sqlite are gone.
  - superpowers skills installed. spider manages ~/.pi/agent/AGENTS.md.
  - Update spider later with: git -C "$SPIDER_DIR" pull && (cd "$SPIDER_DIR" && npm run build)
EOF
}
main "$@"
