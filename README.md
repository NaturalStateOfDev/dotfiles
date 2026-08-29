# dotfiles

Cross-platform dotfiles managed with [chezmoi](https://chezmoi.io) —
Omarchy (Hyprland/Arch), WSL, plain Linux, and Windows.

`chezmoi init` asks which machine this is (`omarchy-desktop`, `omarchy-laptop`,
`wsl-work`, `windows-work`, `other-linux`). That answer, not OS sniffing, is
what every conditional reads — OS alone can't tell a personal Omarchy box from
a work one, and `.chezmoi.osRelease` doesn't exist on Windows.

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

## Omarchy notes

Omarchy reports `ID=omarchy` (not `arch`) in `/etc/os-release`; conditionals
must test for `omarchy`. Omarchy ships its own `starship.toml` and terminal
configs — this repo's `starship.toml` deliberately wins, since Omarchy's copy
is static rather than theme-generated. WezTerm is skipped there (foot is the
default terminal, themed by Omarchy).

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
| `dot_wezterm.lua`, `dot_config/wezterm/` | WezTerm config + background assets | Windows + native Linux; skipped in WSL (WezTerm lives host-side). Platform quirks handled inside the config via `target_triple` / WSL-domain detection. Install a CaskaydiaCove Nerd Font for the configured font stack. |
| `dot_config/zsh/omarchy.zsh` | `~/.config/zsh/omarchy.zsh` | Loads the portable parts of Omarchy's bash rc into zsh. Omarchy machines only; see the header for what is deliberately skipped |
| `dot_config/hypr/monitors.lua` | `~/.config/hypr/monitors.lua` | Stacked-ultrawide layout — `omarchy-desktop` only |
| `dot_config/omarchy/shell.toml` | `~/.config/omarchy/shell.toml` | Bar/shell type scale; merged over the active theme so it survives `omarchy theme set` |
| `dot_config/omarchy/hooks/post-update.d/` | Omarchy update hook | Warns when `omarchy update` migrations leave `$HOME` diverged from the source |
| `run_once_before_10-bootstrap.sh.tmpl` | — | new-Linux-machine setup, runs once (apt, pacman, or `omarchy pkg`) |
| `.chezmoi.toml.tmpl` | `~/.config/chezmoi/chezmoi.toml` | prompts once per machine |

## Rules

This repo is public. No secrets, no personal information, no
employer-specific values — ever. Machine-local config belongs in
`~/.zshrc.local`; per-machine identity in chezmoi template data.
