# Chief-of-Staff Agent Team — Design

Date: 2026-08-27
Status: implemented on feat/staff-agents

## Goal

A coordinator subagent ("chief of staff") usable from any local project that
breaks work into subtasks, delegates each to a specialist subagent, verifies
the results, and keeps a written record. The chief also periodically reviews
its own team (on request) and proposes additions, merges, and retirements.

## Non-goals

- Background/scheduled execution (no cron, no `/loop`). Everything is on demand.
- Cloudflare deployment checks (not needed today).
- Merging PRs automatically; the user merges.
- Agents editing other agent definitions without explicit user approval.
- Replacing existing plugin agents (`feature-dev:code-reviewer`,
  `github-manager`); the team delegates to read-only ones where useful.

## Location and sync

- All definitions live in `~/.claude/agents/*.md` (user scope, every project).
- Repo-only paths (`README.md`, `CLAUDE.md`, `docs/`, `scripts/`) are listed in
  `.chezmoiignore` so they are never applied to `$HOME`.
- `~/.claude/staff/projects.yaml` is the machine-local project registry and is
  excluded from chezmoi.
- `~/.claude/agents/` is added to chezmoi so the team syncs across machines.
  The repo is public: agent files contain no secrets, hostnames, or employer
  values. Stack-specific knowledge is expressed generically ("Terraform + ECS",
  "dbt project") and the agents read repo-local docs for specifics.
- A `~/.claude/skills/staff/SKILL.md` skill provides the `/staff` entry point
  and is also chezmoi-managed.
- Project-specific overrides may be placed in `<repo>/.claude/agents/` and take
  precedence per Claude Code's normal resolution.

## Roster

| Agent | Purpose | `model` | Key frontmatter |
|---|---|---|---|
| `chief-of-staff` | Intake, decomposition, delegation, verification, ledger upkeep | `fable` | `memory: project` |
| `task-documenter` | Task records; light-touch upkeep of `docs/` and CLAUDE.md | `opus` | — |
| `staff-reviewer` | Diff review orchestrator; runs two read-only `feature-dev:code-reviewer` passes (correctness/security, simplification) | `opus` | `disallowedTools: Edit, Write` (report only); never spawns agents that have Edit/Write |
| `deploy-checker` | Pre/post-deploy verification, read-only | `opus` | `disallowedTools: Edit, Write` |
| `ticket-implementer` | Implements one ticket in its own worktree, TDD, opens one PR | `opus` | — (the chief creates the worktree with `git -C` and passes its path in the prompt) |
| `pr-janitor` | Post-merge cleanup; removes worktrees | `sonnet` | — |
| `staff-auditor` | Self-review of the team; suggest-first | `fable` | `disallowedTools: Edit` (may `Write` only its report file) |

Bash-level mutation in read-only agents is prompt-guarded only (frontmatter
cannot deny individual Bash commands); a PreToolUse hook is the upgrade path
if needed.

### chief-of-staff

Responsibilities, in order, for each request:

1. **Intake** — restate the task in one paragraph; identify the repo, branch,
   and whether a ledger exists (`docs/staff/ledger.md`). Create it if not.
2. **Decompose** — produce a numbered subtask list. Each subtask names the
   specialist, the model tier, and the done-criterion.
3. **Delegate** — spawn specialists via the Agent tool, in parallel where
   independent. Pass the model override chosen by the routing rubric.
4. **Verify** — read each specialist's report; re-run or re-delegate if a
   done-criterion is unmet. Never mark done on a specialist's say-so alone
   when a cheap check exists (tests, `gh pr checks`, file existence).
5. **Record** — pull `default_branch` ff-only, then append/update the ledger
   entry and commit it as `staff: ledger T-nnn` (or, where direct commits to
   that branch are not allowed, write the row in the ticket's worktree so it
   ships with the PR); ask `task-documenter` to write the task record if the
   task is more than a one-liner.
6. **Report** — a short recap to the user: what was done, evidence, what is
   open.

Model routing rubric (used for the Agent-tool `model` override):

| Tier | Use when |
|---|---|
| `sonnet` | Mechanical, single-file, cleanup, formatting, ledger edits |
| `opus` (default) | Code review, documentation, deploy analysis, multi-file changes with clear spec |
| `fable` | Architecture, ambiguous requirements, cross-cutting refactors, anything needing design judgment or a UI/UX decision |

The chief states the tier it chose and why in the ledger entry.

Staff review trigger: when the user asks ("run a staff review", "/staff
review"), the chief delegates to `staff-auditor` and then relays the report;
it applies approved changes itself only after the user says yes.

### task-documenter

Writes `docs/staff/tasks/<id>-<slug>.md` with: summary, why, decisions taken,
files touched, how to verify, follow-ups. Also: updates README/CLAUDE.md only
where a statement has become false (never rewrites for style), and reports
any doc it found stale but did not touch.

### staff-reviewer

Given a diff or PR: runs two read-only `feature-dev:code-reviewer` passes
(correctness/security; simplification, report-only), dedupes findings, ranks
by severity, checks the ~400-line size guard, and returns a single report
with file:line anchors. Read-only — it never spawns an agent that can edit
(so `pre-pr-simplifier`, which has all tools, is not used here).

### deploy-checker

Order of operations:

1. Read the repo's own deploy docs (README, CLAUDE.md, `docs/`, Makefile,
   `.github/workflows`) and state what the project's deploy path is.
2. GitHub: `gh pr checks` / `gh run list` for the branch; required checks;
   release workflow status.
3. Terraform + ECS projects: `terraform plan` (no apply) for drift; ECS
   service desired vs running count and last deployment status; confirm
   referenced SSM parameter names exist (values never printed).
4. dbt projects only, and only with an explicit non-production `--target`
   (dev profile target or `$DBT_TARGET`): `dbt build --select state:modified+`
   where a state manifest exists, else `dbt build`; report test failures and
   freshness. No non-prod target resolvable → check is `skipped`.
5. Emit a go / no-go with evidence. Never applies, deploys, or mutates.

### pr-janitor

After a PR is merged (the chief spawns it when the user reports the merge or
runs `/staff cleanup <PR>`): verify the PR is merged, delete its local and
remote branch, remove its worktree, list other `[gone]` branches without
deleting them (sibling tickets may be mid-flight), close linked issues if
`Closes #n` was not already honoured, mark the ledger row and task record
done, and list follow-ups from the merge commit diff (TODOs, skipped tests).

### staff-auditor

Inputs: all `~/.claude/agents/*.md`, `docs/staff/ledger.md` of the current
repo, and the `## Watching` section. Produces
`docs/staff/reviews/YYYY-MM-DD.md` containing:

- Usage table: specialist × count × models used × outcome.
- Proposals: **add** (recurring ad-hoc work with no specialist), **merge**
  (overlapping specialists), **retire** (unused for 90 days or superseded),
  **tune** (rubric or prompt tweaks with evidence).
- Stale docs list.
- Watching items past their next-check date.

It writes only that report file; agent-definition changes are applied by the
chief after user approval.

### ticket-implementer

Given a ticket key, a worktree path, and the chief's brief: reads the ticket
(Atlassian MCP, or a project-specific Jira skill, if installed), works only
inside its worktree, follows TDD, commits with the ticket key as prefix,
pushes the branch, and opens a draft PR titled `<KEY>: <summary>` with a body
that links the ticket and lists verification steps. Reports the PR URL and
diff stats. It does not touch other worktrees and does not merge.

## Multi-ticket dispatch

Typical invocation from `~` (or anywhere):

> on example-app, fix XYZ-1234 and implement XYZ-567 and ZYX-789

Chief behaviour:

1. **Resolve project** via `~/.claude/staff/projects.yaml` (machine-local,
   never synced; one entry per repo: `name`, `path`, `default_branch`,
   `ticket_prefixes`, `deploy: [github, terraform-ecs, dbt]`). If the name
   is unknown, ask once and offer to add it.
2. **Fetch tickets** and summarize each in one line; flag any with missing
   acceptance criteria.
3. **Plan the batch** — one worktree/branch/PR per ticket by default. Detect
   overlap by asking each ticket's likely touched files (grep of the
   codebase against ticket text); overlapping tickets are serialized and the
   later PR is stacked on the earlier branch. Present the batch plan
   (ticket → branch → parallel/serial → model tier) and wait for one "go".
4. **Create worktrees** for the independent tickets and the head of each
   dependency chain only: `git -C <path> fetch origin` then
   `git -C <path> worktree add ../<repo>-<KEY> -b <KEY>/<slug> origin/<default_branch>`.
   A dependent ticket's base does not exist on `origin` yet, so its worktree
   is created in step 5 from `origin/<earlier-branch>` once the earlier
   implementer has reported.
5. **Spawn `ticket-implementer`** per ticket, in parallel where independent,
   each with its worktree path in the prompt and the model tier from the
   rubric.
6. **Per PR**: `staff-reviewer` then `deploy-checker`; findings go back to the
   same implementer for one fix round before escalating to the user.
7. **Size guard**: a PR over ~400 changed lines (excluding lockfiles and
   generated code) or mixing unrelated concerns must be split into stacked
   PRs before leaving draft. The chief states the split in the ledger.
8. **Recap**: table of ticket → PR URL → review status → deploy check.
   Ledger updated and committed with one row per ticket.

After merge, `pr-janitor` removes the worktree (`git worktree remove`) and
branch, and the chief moves any leftover items to `## Watching`.

## Ledger format

`docs/staff/ledger.md` in each repo:

```markdown
# Staff ledger

## Tasks
| id | date | status | task | specialists (model) | outcome / evidence |
|----|------|--------|------|---------------------|--------------------|
| T-001 | 2026-08-27 | done | Add OIDC env vars | deploy-checker (opus), task-documenter (sonnet) | PR #12 merged, checks green |

## Watching
| item | owner agent | next check | notes |
|------|-------------|------------|-------|
| Terraform module upgrade to v3 | deploy-checker | 2026-09-15 | waiting on upstream release |
```

IDs are `T-` plus a zero-padded counter per repo. Status is one of
`open`, `blocked`, `done`, `dropped`.

## `/staff` skill

A short SKILL.md that documents the entry points and routes to the chief:

- `/staff <task>` — delegate a task.
- `/staff review` — run a staff audit.
- `/staff status` — summarize open ledger items and overdue watches.

## Error handling

- A specialist returning nothing or failing → chief retries once with the
  next tier up, then reports the gap rather than guessing.
- Missing tooling (`gh`, `terraform`, `dbt` not on PATH or unauthenticated) →
  deploy-checker reports the step as skipped with the reason; never a
  silent pass.
- Ledger merge conflicts are avoided by append-only rows and editing a row
  only by id.

## Testing / acceptance

1. `/agents` lists all seven with no frontmatter errors.
2. In a small real repo: `/staff <trivial task>` creates the ledger, spawns
   at least `task-documenter`, and produces a recap with evidence.
3. `/staff review` writes `docs/staff/reviews/<date>.md` and makes no other
   changes.
4. `deploy-checker` on a Terraform+ECS repo returns a go/no-go without
   mutating state (verify with `terraform show` unchanged and `git status`
   clean).
5. From `~`, `/staff on <project>, do <two independent tickets>` produces two
   worktrees, two branches, two draft PRs, and a ledger row each; no shared
   commits between the branches.
6. `chezmoi status` is clean after `chezmoi add ~/.claude/agents
   ~/.claude/skills/staff`; a grep of the added files for hostnames,
   account IDs, or company names returns nothing.
