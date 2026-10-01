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
- Agent specifics (names, repos, accounts, ports) go in `~/.claude/local/<agent>.md`,
  an unsynced overlay each synced agent reads; project conventions go in the repo's
  own `CLAUDE.md`. Never scrub-and-sync: the synced layer stays generic by design.
- Use the `/dotfiles` skill for the sync/drift workflow.

## Git workflow & versioning (every repo)
The default for all repos. A repo's own `CLAUDE.md` adds its specifics (deploy
triggers, test commands, CI quirks) and wins where it explicitly differs.

- **Branches:** `main` = production, `develop` = integration / dev environment.
  Work on short-lived branches cut from `origin/develop`, named
  `<TICKET-KEY>/<short-slug>`. Never commit to `main` or `develop` directly,
  and don't stack a PR on another feature branch: always base on and target `develop`.
- **Merging:** feature → `develop` is a **squash merge**, with one commit per
  ticket. `develop` → `main` is a **merge commit**, and its PR body aggregates
  the changelog entries since the last release.
- **Versions:** SemVer `vX.Y.Z`, pre-1.0 for now. Two tag lines that stay in sync:
  - `main`: `vX.Y.Z`, a production release. Tag the `develop → main` merge commit.
  - `develop`: `vX.Y.Z-dev.N`. Tag each squash commit after it lands, and bump N per PR.
  - **Invariant:** the `X.Y.Z` in the dev tags is the release in progress and
    must equal the next `main` tag, so `v0.4.0-dev.7` ships as `v0.4.0`. After a
    release, start the next cycle at `-dev.1`.
  - **Choosing X.Y.Z** (bump from the last `main` release): MAJOR for breaking
    changes (stays 0 pre-1.0), MINOR for backward-compatible features, PATCH
    for fixes only.
  - **Retarget** if scope grows mid-cycle: start `vX.(Y+1).0-dev.1` and leave the
    old dev tags as never-shipped history. Never ship under a different number
    than the dev stream used.
- **Tags:** annotated. The message is `vX.Y.Z-dev.N — <short title> (<TICKET>)`,
  then a `Changelog:` block lifted from the PR. Push each tag explicitly with
  `git push origin <tag>`.
- **Changelog:** every PR body ends with a `## Changelog` section written in plain
  words. If the repo has a `CHANGELOG.md`, the PR also adds its entry at the top,
  as `## vX.Y.Z-dev.N (YYYY-MM-DD)` with one bullet per change ending in the
  ticket key, and the tag must equal that top heading. Apps that show their
  version should read it from that file, not from git tags: the dev image is
  often built before the tag exists.
