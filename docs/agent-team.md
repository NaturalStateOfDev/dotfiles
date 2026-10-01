# Claude Code agent team

How the `/alfred` team in `dot_claude/agents/` works, and why it is built this way. Repo-only documentation (ignored by chezmoi); nothing here is applied to `$HOME`.

## Roles

| Agent | Model | Job |
|---|---|---|
| `alfred` | opus | Coordinator. Resolves the project, plans a batch, spawns specialists, verifies their claims, keeps the project's records and the ticket tracker current. Never writes app code itself. |
| `ticket-implementer` | opus | One ticket, one git worktree, TDD, one draft PR. |
| `pre-pr-simplifier` | opus | Behaviour-preserving simplification of the branch's diff. Stack-aware (dbt, Django). |
| `staff-reviewer` | opus | Read-only review orchestrator: ranked findings with `file:line`. |
| `deploy-checker` | opus | Read-only go/no-go: CI, Terraform plan drift, ECS health, dbt build. |
| `task-documenter` | opus | Local task record, plus fixes to repo docs the change made false. |
| `pr-janitor` | sonnet | Post-merge cleanup: worktree, branches, the merge record. |
| `staff-auditor` | opus | Self-review of the team; suggest-only. |

`opus` is the ceiling. `fable` is never used, because it exhausts session limits. Implementers are never downgraded to save tokens. Failure handling: retry once at the next tier up; an `opus` failure gets one sharper `opus` retry, then it is reported as blocked.

## Pipeline

```
write code (TDD) → tests + pre-commit --all-files → simplify → review → deploy check
  → docs → view on localhost → human merges → deploy
```

- **Simplify before review.** The simplifier must reproduce the implementer's exact test pass count and may never weaken a test. It commits `<KEY>: simplify (no behaviour change)`, or makes no commit when there's nothing worth changing. It's skipped for diffs under ~40 lines and for docs/config/migration-only diffs.
- **Review without duplication.** When the simplifier has run, the reviewer skips its own simplification pass. Its correctness pass still covers the whole diff, including the simplifier's commit.
- **One fix round.** High-severity findings go back to the same implementer once; anything still failing goes to the human.
- **Localhost before merge.** The default branch deploys to a shared environment, so every PR is served from its own worktree and looked at locally before it merges.
- **Humans merge, apply and force-push.** Agents never do.

## Layers: what lives where

| Layer | Location | Synced? | Holds |
|---|---|---|---|
| Generic agents | `~/.claude/agents/*.md` | yes (this repo) | workflow, safety rules, stack-level conventions |
| Local overlays | `~/.claude/local/<agent>.md` | **no** | names, repos, accounts, ports, employer-specific conventions |
| Project conventions | `<repo>/CLAUDE.md` | in that project's repo | rules the project's team also needs |
| Memory | `~/.claude/projects/*/memory/` | no | facts learned across sessions |
| Records | an Obsidian vault project folder ("vault mode"), else `~/.claude/staff/<slug>/` | no | vault mode: the hub note's `## Log`, follow-up task notes in `Tasks/`, task records and reviews in `Agent Records/`; fallback: a local ledger, task records, reviews |
| Staff dir | `~/.claude/staff/<slug>/` | no | `projects.yaml`, agent working notes, assets |

Every synced agent reads its overlay, if one exists, right after its frontmatter; the overlay wins where it is more specific. Overlays point to memory files rather than copying them, so each fact has one home.

**No scrub-and-sync.** Specifics are never written into a synced file and then stripped later. A manual scrub drifts, leaks, and gets skipped. If a rule only makes sense with a project's names in it, it belongs in the overlay or in the project's `CLAUDE.md`.

## Ticket tracker rules

- Every piece of work maps to a ticket. Work with no ticket is `untracked`; it is proposed to the human, never started silently.
- On the human's own tickets, agents keep the tracker current without asking: status transitions as the work moves, short status comments, and description edits. Done needs a merged PR.
- **Never @-mention anyone** without a per-item OK, so the human knows whose reply to expect.
- Other people's tickets, creating tickets, assignee changes, deletes and worklogs all need a per-item OK.
- Reads go through a compact, batched CLI where one is available: one call per batch, with an explicit field projection. They fall back to MCP only after two failures.

## Localhost conventions

- Serve a branch from its own worktree; don't move the main checkout. Pin `COMPOSE_PROJECT_NAME` to the main checkout's project name, so the image is reused while the bind mount resolves to the worktree.
- Each worktree needs its own copy of the gitignored `.env`.
- To run two projects at once without editing a framework-managed compose file: keep a local override (`ports: !override`) outside the repo, and load it with a `COMPOSE_FILE=docker-compose.yml:<override>` line in that project's `.env`. Worktrees inherit it when they copy `.env`.
- Local test data is free to create; shared environments are not.

## Maintenance

- Lint agent files before committing: `scripts/check-agents.sh`.
- A new synced agent gets the one-line overlay pointer after its frontmatter.
- `/alfred review` runs `staff-auditor`, which proposes agents to add, merge, retire or tune.
