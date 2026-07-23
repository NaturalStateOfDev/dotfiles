---
name: dotfiles
description: Sync, inspect drift, and update chezmoi-managed dotfiles. Use when the user runs /dotfiles or asks to sync dotfiles, resolve config drift, add a file to the dotfiles repo, or set up a new machine.
---

# Dotfiles sync & drift resolution

Dotfiles are managed by chezmoi. Source directory: `~/.local/share/chezmoi`
(a git repo synced to a public GitHub repository).

## Sync flow
1. `chezmoi status` and `chezmoi diff` — list local drift (target vs. source).
2. Classify each difference and act:
   - Local edit worth keeping → `chezmoi re-add <file>` (source takes the local version).
   - Unwanted local drift → `chezmoi apply <file>` (local file reset to source).
   - Both sides changed → `chezmoi merge <file>` (three-way merge in $EDITOR).
   - Tool-appended lines in `.zshrc` (installers love doing this) → usually move
     the addition to `~/.zshrc.local`, then `chezmoi apply ~/.zshrc`.
3. `chezmoi update` — pull remote changes and apply them.
4. Publish: `chezmoi cd`, then `git add -A && git commit && git push`
   (or `chezmoi git -- <args>` without changing directory).

## Adding a new file
1. Scan it for secrets and personal/employer-specific content FIRST. If found,
   externalize (e.g. `~/.zshrc.local`) or convert values to template data.
2. `chezmoi add <file>` (`--template` if it needs per-machine values).
3. Decide whether Windows machines should skip it → update `.chezmoiignore`.

## Hard rules
- The repo is public: never commit secrets, tokens, hostnames of private
  infrastructure, employer names, or personal information.
- Machine identity (git name/email, work flag) lives only in
  `~/.config/chezmoi/chezmoi.toml`, generated from `.chezmoi.toml.tmpl`.
- Verify before pushing: `chezmoi doctor` is clean and
  `git grep -iE 'password|secret|token|api.?key'` over the source repo is empty.
