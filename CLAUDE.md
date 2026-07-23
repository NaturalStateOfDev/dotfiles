# Working in this dotfiles repo

This is a chezmoi source directory, synced to a PUBLIC GitHub repo.
`README.md` documents the layout. Conventions for changes:

## Naming
- `dot_` prefix maps to a leading `.` in `$HOME` (`dot_zshrc` → `~/.zshrc`).
- `.tmpl` suffix = Go template rendered with per-machine data. Available keys:
  `.name`, `.email` (git identity), `.work` (bool), plus chezmoi built-ins
  (`.chezmoi.os`, `.chezmoi.hostname`, …).
- `run_once_before_*` scripts execute once per machine, before files apply.
- Shell alias naming scheme: one-letter tool prefix + short real word
  (`gsync`, `dclean`) — see `dot_oh-my-zsh/custom/aliases.zsh`.

## Hard rules
- PUBLIC repo: no secrets, no personal information, no employer-specific
  values in any file. Per-machine values go in template data
  (`.chezmoi.toml.tmpl` prompts) or stay in unmanaged `~/.zshrc.local`.
- `README.md` and `CLAUDE.md` are listed in `.chezmoiignore` — keep it that
  way so they never land in `$HOME`.
- Windows machines skip zsh-related files via `.chezmoiignore` conditionals;
  every new file needs a deliberate Windows decision.

## Verifying changes
- `chezmoi diff` — what would change in `$HOME` (empty = source matches home).
- `chezmoi execute-template < file.tmpl` — render a template with this
  machine's data.
- `chezmoi apply --dry-run --verbose` — rehearse an apply.
- `chezmoi doctor` — config sanity check.
- Before any push: `git grep -iE 'password|secret|token|api.?key'` must be empty.
