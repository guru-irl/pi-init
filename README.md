# pi-init

One-shot bootstrap for a fresh machine: [pi](https://github.com/earendil-works) +
[superpowers skills](https://github.com/guru-irl/superpowers) + context-mode
(`ctx_*`) + pi-subagents + [pi-todo-sqlite](https://github.com/guru-irl/pi-todo-sqlite)
+ [pi-ctx-ui](https://github.com/guru-irl/pi-ctx-ui), plus optional GitHub Copilot CLI wiring.

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
```

## What it installs

- Node (system package manager, if missing) + pi (`@earendil-works/pi-coding-agent`)
- pi packages: `pi-subagents`, `context-mode`, `pi-todo-sqlite` (durable per-project todos + `/todos`)
- `pi-ctx-ui` local extension (nicer `ctx_*` tool UI)
- context-mode MCP server (global) for any agent
- superpowers skills (`guru-irl/superpowers`) for pi / Claude Code / Copilot CLI
- GitHub CLI auth + optional GitHub Copilot CLI wiring
- pi global bootstrap prompt (`~/.pi/agent/AGENTS.md`)

The script is idempotent — safe to re-run to update.
