# Global preferences

## Shell & environment
- zsh + oh-my-zsh; personal aliases live in `~/.oh-my-zsh/custom/aliases.zsh`.
- Alias naming scheme: one-letter tool prefix + short real word (`gsync`, `dclean`,
  `kctx`). Terse abbreviations (`gcm`, `gl`, `gst`, …) belong to omz plugins —
  run `type <name>` to confirm a name is free before claiming it.
- Secrets and machine-/employer-specific shell config go in `~/.zshrc.local`
  (sourced last, never synced). Never add secrets to a synced file.

## Dotfiles
- Managed with chezmoi; source directory `~/.local/share/chezmoi` (a git repo
  synced to a public GitHub repository).
- Edit managed files with `chezmoi edit <file>`, or edit in place and
  `chezmoi re-add <file>`. Check drift with `chezmoi status` / `chezmoi diff`.
- The repo is public: no secrets, no personal information, no employer-specific
  values in any synced file. Per-machine values belong in chezmoi template data
  (`~/.config/chezmoi/chezmoi.toml`) or `~/.zshrc.local`.
- Use the `/dotfiles` skill for the sync/drift workflow.
