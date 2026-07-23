# dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io) —
Linux (zsh / oh-my-zsh / starship) and Windows (WezTerm, Claude Code).

## New Linux machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply NaturalStateOfDev
```

That installs chezmoi, clones this repo, runs the bootstrap script
(packages, oh-my-zsh + plugins, starship), prompts for machine identity
(git name/email, work machine y/n), and applies everything.

## Windows machine

```powershell
winget install twpayne.chezmoi
chezmoi init --apply NaturalStateOfDev
```

Windows machines only receive the cross-platform files (WezTerm, Claude
Code, git config) — zsh-related files are skipped via `.chezmoiignore`.

## Already-configured machine (adopting, not overwriting)

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init NaturalStateOfDev   # note: no --apply
chezmoi diff          # see what apply WOULD change — nothing has happened yet
chezmoi apply <file>  # adopt file-by-file, or:
chezmoi merge <file>  # reconcile when both versions have good parts
```

## Layout

| Source | Applies to | Notes |
|---|---|---|
| `dot_zshrc` | `~/.zshrc` | sources `~/.zshrc.local` (machine-local, never synced) last |
| `dot_oh-my-zsh/custom/aliases.zsh` | omz custom dir | alias naming scheme documented in-file |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | name/email from per-machine template data |
| `dot_config/starship.toml` | `~/.config/starship.toml` | prompt config |
| `dot_claude/` | `~/.claude/` | global CLAUDE.md + `/dotfiles` skill |
| `run_once_before_10-bootstrap.sh.tmpl` | — | new-Linux-machine setup, runs once |
| `.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | prompts once per machine |

## Rules

This repo is public. No secrets, no personal information, no
employer-specific values — ever. Machine-local config belongs in
`~/.zshrc.local`; per-machine identity in chezmoi template data.
