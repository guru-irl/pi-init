# pi-init

One-shot **spider-first** bootstrap for a fresh machine: [pi](https://github.com/earendil-works) +
[spider](https://github.com/guru-irl/spider) (the unified extension — subagents, memory, unified
search, todos, sandboxed exec, web fetch) + [superpowers skills](https://github.com/guru-irl/superpowers),
plus optional GitHub Copilot CLI wiring.

spider **replaces** the old `pi-subagents`, `context-mode` (`ctx_*`), and `pi-todo-sqlite`
extensions — this script installs spider instead and prunes those from an existing setup.

## Quick install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/guru-irl/pi-init/main/init.sh)
```

`bash <(curl …)` keeps your terminal attached to stdin so interactive `gh` / `pi`
logins work (unlike `curl … | bash`).

### Options

```bash
GH_TOKEN=ghp_xxx bash <(curl -fsSL https://raw.githubusercontent.com/guru-irl/pi-init/main/init.sh)   # non-interactive gh auth
SKIP_COPILOT_CLI=1 bash <(curl -fsSL https://raw.githubusercontent.com/guru-irl/pi-init/main/init.sh) # skip Copilot CLI
SPIDER_REPO=… SPIDER_DIR=… bash <(curl …)                                                             # override spider clone source/dir
```

## What it installs

- Node (system package manager, if missing) + pi (`@earendil-works/pi-coding-agent`)
- **spider** — cloned to `~/.local/share/spider`, built, and dev-linked into pi
  (`~/.pi/agent/extensions/spider.ts`). One extension for subagents, memory,
  unified search, durable todos (`/todos`), sandboxed exec, and web fetch, on a
  shared SQLite DB.
- companion pi packages: `pi-intercom`, `pi-prompt-template-model`
- superpowers skills (`guru-irl/superpowers`) for pi / Claude Code / Copilot CLI
- GitHub CLI auth + optional GitHub Copilot CLI
- spider-managed global guide (`~/.pi/agent/AGENTS.md`)

Re-running migrates an old setup: it prunes `pi-subagents`, `context-mode`, and
`pi-todo-sqlite` from `~/.pi/agent/settings.json` (backed up to `settings.json.bak`).

The script is idempotent — safe to re-run to update (spider is `git pull`ed + rebuilt).
