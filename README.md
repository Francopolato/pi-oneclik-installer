# Pi Portable Installer (one click)

One-click installer for the [pi](https://pi.dev) coding agent on a **bare Windows PC** — no Node, no Git, no dev knowledge required. Everything is **portable**: no system installs, no registry writes, nothing in `%USERPROFILE%` except (optionally) the install folder itself. Delete one folder to remove everything.

Built for non-programmers who just want to vibe code: every step is announced in plain text, the extension choice is a simple `y/n` menu.

## Files

| File | What it is |
|---|---|
| `Install Pi.cmd` | The one-click entry point. Double-click it in Explorer. |
| `Install-Pi.ps1` | The installer itself (called by the .cmd). Must sit in the same folder. |

To use: save both files into one folder and double-click **`Install Pi.cmd`**.

## What the installer does (each step printed on screen)

1. **Preflight** — checks 64-bit Windows, warns about ~500 MB disk and internet need.
2. **Node.js** — queries `nodejs.org/dist/index.json`, picks the latest LTS `>= 22.19` (pi requires it), downloads the `win-x64` zip, unpacks into `<root>\node`. Skipped if a new-enough Node is already there.
3. **Git for Windows (Portable)** — queries GitHub's latest release, downloads `PortableGit-*-64-bit.7z.exe` and extracts it **headlessly via the self-extracting archive** (`-y -o`). Zero registry entries, zero PATH pollution. Provides `git.exe` and Git Bash.
4. **pi core** — `npm install -g --prefix <root>\npm-global @earendil-works/pi-coding-agent` using the portable npm.
5. **Launchers + config** — writes relocatable `pi.cmd` and `Launch Pi.cmd` (use `%~dp0`, so the folder can be moved anywhere) and `pi-home\settings.json`:
   - `defaultTools` = `["read","powershell","edit","write"]` — **powershell replaces the bash tool**;
   - `shellPath` = `<root>\git\bin\bash.exe` — Git Bash still serves `!`/`!!` commands, git itself and `git:` package sources;
   - existing `settings.json` is **auto-healed** instead of overwritten (bash→powershell, stale `shellPath` refreshed).
6. **Extensions** — always installs **`npm:pi-web-access`** (web search is NOT built into pi core), then asks `y/n` for:
   - `npm:pi-lens` — code diagnostics, AST search, symbol navigation
   - `npm:pi-mcp-adapter` — connect MCP servers
   - `npm:pi-subagents` — sub-agents and parallel workflows
   - `npm:pi-browser-cdp-extension` — Chrome via DevTools protocol
   - `npm:pi-local-rag` — ask questions about your own documents
   plus a free "other sources" input (`npm:name`, `git:owner/repo`, or URL).
7. **Summary** — how to launch, the `/login` requirement, where everything lives.

## Menu

`Install Pi.cmd` asks one question first:

```
1 = install / repair     2 = update pi + packages     3 = UNINSTALL everything
```

- Re-run `1` on an existing install = safe repair (re-creates launchers, heals settings).
- `2` = updates pi core via the portable npm and reconciles installed packages (`pi update --extensions`).
- `3` = shows the folder contents, deletes the folder, then scans `%USERPROFILE%\.pi`, `.npm`, `.gitconfig` for leftovers and asks about those.

## Folder layout (everything self-contained)

```
<root>\
├── node\            portable Node.js LTS (>= 22.19)
├── git\             Git for Windows Portable (cmd\git.exe, bin\bash.exe)
├── npm-global\      pi itself + its node_modules
├── pi-home\         ALL pi state: settings.json, sessions, packages, auth, gitconfig
├── cache\npm\       npm cache (npm never writes in %USERPROFILE%)
├── pi.cmd           relocated launcher: sets PI_CODING_AGENT_DIR etc, runs cli.js
└── Launch Pi.cmd    double-click to start pi in that folder
```

Isolation is done with environment redirection (set by the launchers and the installer):
`PI_CODING_AGENT_DIR`, `PI_CODING_AGENT_SESSION_DIR`, `NPM_CONFIG_CACHE`, `GIT_CONFIG_GLOBAL`.

## Using pi afterwards

- Double-click `Launch Pi.cmd` (opens pi in a terminal window; copy it into a project folder to work there).
- First step inside pi: **`/login`** — without a provider (API key / subscription) pi cannot answer.
- `/model` to pick a model, then describe your task in plain language.

## Requirements it cannot avoid

- 64-bit Windows 10/11 (PowerShell is a given there).
- Internet at install time **and** while pi runs (model catalog + provider calls).
- ~500 MB of disk (Node ~120 MB, Git ~300 MB, pi ~80 MB).

## Why these pieces

| Piece | Needed because |
|---|---|
| Node ≥ 22.19 | pi's only hard runtime dependency |
| Portable Git | Git Bash (`!` commands), `git:` sources, code history — not strictly required by pi core |
| `pi-web-access` | web search is an extension, not core |
| `powershell` tool | the bash tool is replaced for the model; Windows always has PowerShell |

No `gh`, no admin rights, no MSI/NSIS installers with registry side effects — Git for Windows is installed *only* in its Portable (7z SFX) form.
