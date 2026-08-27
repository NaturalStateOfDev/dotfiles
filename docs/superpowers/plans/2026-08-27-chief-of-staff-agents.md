# Chief-of-Staff Agent Team Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a chezmoi-synced team of seven Claude Code subagents (a `chief-of-staff` coordinator plus six specialists) and a `/staff` skill that dispatch multi-ticket work into isolated worktrees, one PR per ticket, with a per-repo ledger.

**Architecture:** Every agent is a markdown file with YAML frontmatter in `~/.claude/agents/`, authored in the chezmoi source dir (`~/.local/share/chezmoi/dot_claude/agents/`) and applied with `chezmoi apply`. The chief delegates via the Agent tool with per-call `model` overrides; specialists are single-purpose and mostly read-only. A machine-local `~/.claude/staff/projects.yaml` maps project names to repo paths and is excluded from chezmoi. A lint script in the dotfiles repo validates frontmatter and public-repo hygiene and is the test for every task.

**Tech Stack:** Claude Code subagents (markdown + YAML frontmatter), chezmoi, bash, `gh`, `git worktree`, Atlassian MCP.

**Spec:** `docs/superpowers/specs/2026-08-27-chief-of-staff-agents-design.md`

> **Note:** the agent bodies and lint script embedded below are the original drafts. Review rounds changed them; `dot_claude/agents/*.md`, `dot_claude/skills/staff/SKILL.md`, and `scripts/check-agents.sh` are authoritative.

## Global Constraints

- Repo is public: no secrets, hostnames, account IDs, or company/employer names in any file under `dot_claude/`. Stack knowledge is generic ("Terraform + ECS", "dbt project").
- Agent `model:` values are limited to `fable`, `opus`, `sonnet`, `haiku`, `inherit`.
- `deploy-checker`, `staff-reviewer` never mutate: `disallowedTools: Edit, Write` and prompt says so. `staff-auditor`: `disallowedTools: Edit`.
- No PR is merged by any agent; the user merges.
- Ledger path is always `docs/staff/ledger.md` relative to the target repo; task records in `docs/staff/tasks/`, audits in `docs/staff/reviews/`.
- One ticket → one worktree → one branch `<KEY>/<slug>` → one draft PR titled `<KEY>: <summary>`.
- PR size guard: ~400 changed lines excluding lockfiles/generated code.
- All work happens in `~/.local/share/chezmoi`; after each task run `chezmoi apply` so `~/.claude` reflects source. Commit after each task; do not push.

---

## File structure

| Path (chezmoi source) | Target | Responsibility |
|---|---|---|
| `scripts/check-agents.sh` | (repo only) | Lint: frontmatter fields, model alias, tool restrictions, hygiene grep |
| `dot_claude/agents/chief-of-staff.md` | `~/.claude/agents/chief-of-staff.md` | Coordinator |
| `dot_claude/agents/ticket-implementer.md` | … | Implements one ticket in a worktree |
| `dot_claude/agents/task-documenter.md` | … | Task records, light doc upkeep |
| `dot_claude/agents/staff-reviewer.md` | … | Review orchestrator, read-only |
| `dot_claude/agents/deploy-checker.md` | … | Deploy go/no-go, read-only |
| `dot_claude/agents/pr-janitor.md` | … | Post-merge cleanup |
| `dot_claude/agents/staff-auditor.md` | … | Team self-review, report only |
| `dot_claude/skills/staff/SKILL.md` | `~/.claude/skills/staff/SKILL.md` | `/staff` entry point |
| `dot_claude/staff/projects.example.yaml` | `~/.claude/staff/projects.example.yaml` | Template for the registry |
| `.chezmoiignore` (modify) | — | Exclude `.claude/staff/projects.yaml` |
| `README.md` (modify) | — | Document the team |

Existing user agents `github-manager.md` and `pre-pr-simplifier.md` stay untracked by chezmoi in this plan (they were authored for a specific employer stack; adding them is a separate decision).

---

### Task 1: Lint script (the test harness)

**Files:**
- Create: `scripts/check-agents.sh`

**Interfaces:**
- Produces: `scripts/check-agents.sh [dir]` — exits 0 when every `*.md` in `dir` (default `dot_claude/agents`) passes; prints `FAIL <file>: <reason>` otherwise. Later tasks run it as their test.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Lint Claude Code subagent files for frontmatter validity and public-repo hygiene.
set -euo pipefail
dir="${1:-dot_claude/agents}"
fail=0
say_fail() { echo "FAIL $1: $2"; fail=1; }

for f in "$dir"/*.md; do
  [ -e "$f" ] || { echo "no agent files in $dir"; exit 1; }
  # frontmatter is lines between the first two '---' lines
  fm=$(awk 'NR==1 && $0!="---"{exit 1} NR>1 && $0=="---"{exit} NR>1{print}' "$f") \
    || { say_fail "$f" "missing frontmatter"; continue; }
  name=$(grep -E '^name:' <<<"$fm" | sed 's/^name:[[:space:]]*//') || true
  [ -n "$name" ] || say_fail "$f" "missing name"
  [ "$name" = "$(basename "$f" .md)" ] || say_fail "$f" "name '$name' != filename"
  grep -qE '^description:[[:space:]]*\S' <<<"$fm" || say_fail "$f" "missing description"
  model=$(grep -E '^model:' <<<"$fm" | sed 's/^model:[[:space:]]*//') || true
  case "$model" in
    fable|opus|sonnet|haiku|inherit) ;;
    *) say_fail "$f" "model '$model' not in fable|opus|sonnet|haiku|inherit" ;;
  esac
  # read-only agents must block Edit and Write
  case "$name" in
    deploy-checker|staff-reviewer)
      grep -qE '^disallowedTools:.*\bEdit\b' <<<"$fm" && grep -qE '^disallowedTools:.*\bWrite\b' <<<"$fm" \
        || say_fail "$f" "must set disallowedTools: Edit, Write" ;;
    staff-auditor)
      grep -qE '^disallowedTools:.*\bEdit\b' <<<"$fm" || say_fail "$f" "must set disallowedTools: Edit" ;;
  esac
  # body must exist
  [ "$(awk 'c>=2{print} /^---$/{c++}' "$f" | grep -c .)" -gt 5 ] || say_fail "$f" "body too short"
done

# hygiene: patterns that must never appear in synced files
if grep -rniE '[0-9]{12}|\.internal\b|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}' dot_claude/agents dot_claude/skills/staff dot_claude/staff 2>/dev/null; then
  echo "FAIL hygiene: employer/secret-looking pattern found above"; fail=1
fi

[ $fail -eq 0 ] && echo "OK: $(ls "$dir"/*.md | wc -l) agent files pass"
exit $fail
```

- [ ] **Step 2: Make it executable and run it against an empty dir to confirm it fails cleanly**

Run: `cd ~/.local/share/chezmoi && chmod +x scripts/check-agents.sh && mkdir -p dot_claude/agents && ./scripts/check-agents.sh; echo "exit=$?"`
Expected: `no agent files in dot_claude/agents` and `exit=1`.

- [ ] **Step 3: Run it against a deliberately bad file to confirm detection**

Run:
```bash
cd ~/.local/share/chezmoi
printf -- '---\nname: wrong\ndescription: x\nmodel: gpt\n---\nbody\n' > dot_claude/agents/bad.md
./scripts/check-agents.sh; echo "exit=$?"; rm dot_claude/agents/bad.md
```
Expected: three FAIL lines (name != filename, model, body too short) and `exit=1`.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-agents.sh
git commit -m "chore: add subagent lint script"
```

---

### Task 2: chief-of-staff agent

**Files:**
- Create: `dot_claude/agents/chief-of-staff.md`

**Interfaces:**
- Consumes: specialist names defined in Tasks 3–8 (`ticket-implementer`, `task-documenter`, `staff-reviewer`, `deploy-checker`, `pr-janitor`, `staff-auditor`); registry at `~/.claude/staff/projects.yaml` (Task 9 format).
- Produces: the ledger format at `docs/staff/ledger.md` that `pr-janitor`, `task-documenter`, `staff-auditor` read.

- [ ] **Step 1: Write the file**

````markdown
---
name: chief-of-staff
description: "Coordinator that takes a task or a batch of tickets (possibly for a project named by nickname), resolves the repo, breaks the work into subtasks, delegates each to a specialist subagent in its own git worktree, verifies results, and keeps docs/staff/ledger.md current. Use for 'have the chief handle X', '/staff <task>', multi-ticket requests like 'on <project>, fix ABC-123 and implement ABC-456', 'run a staff review', or '/staff status'.\n\n<example>\nuser: \"on example-app, fix XYZ-1234 and implement XYZ-567\"\nassistant: \"I'll hand this to the chief-of-staff agent to plan one worktree/PR per ticket and dispatch implementers.\"\n</example>\n<example>\nuser: \"/staff review\"\nassistant: \"Launching chief-of-staff to run a staff audit via staff-auditor.\"\n</example>"
model: fable
color: purple
memory: project
---

You are the chief of staff for this developer's engineering work. You coordinate; you do not write application code yourself. Your specialists are subagents you spawn with the Agent tool: `ticket-implementer`, `task-documenter`, `staff-reviewer`, `deploy-checker`, `pr-janitor`, `staff-auditor`.

## Operating principles

- Small, isolated changes. One ticket → one worktree → one branch → one draft PR. Never combine tickets into one PR.
- Verify, don't trust. A specialist saying "done" is a claim; check it with the cheapest real signal (tests, `gh pr checks`, `git diff --stat`, file exists).
- Ask once per batch, not once per ticket. Present the batch plan, wait for one "go", then execute without further prompts except for genuinely new decisions.
- Never merge a PR, never transition a Jira ticket to Done, never `terraform apply`, never force-push. The user does those.
- Everything you decide goes in the ledger with evidence.

## Model routing (pass as the Agent tool `model` parameter)

| Tier | Use when |
|---|---|
| `sonnet` | Mechanical, single-file, cleanup, formatting, ledger edits, worktree removal |
| `opus` (default) | Code review, documentation, deploy analysis, multi-file implementation with a clear spec |
| `fable` | Architecture, ambiguous requirements, cross-cutting refactors, UI/UX or design judgment |

State the chosen tier and the reason in the ledger row.

## Procedure for a task or ticket batch

1. **Resolve the project.** If the request names a project by nickname or the cwd is not inside it, read `~/.claude/staff/projects.yaml` (keys: `name`, `path`, `default_branch`, `ticket_prefixes`, `deploy`). Match on `name` case-insensitively and on `ticket_prefixes` against any ticket keys in the request. If nothing matches, ask the user for the path once and offer to append an entry. All later git commands use `git -C <path>`.
2. **Fetch tickets.** For each key matching `[A-Z][A-Z0-9]+-[0-9]+`, fetch summary, description, and acceptance criteria via the Atlassian MCP (`getJiraIssue`) — if a project-specific Jira skill is installed, load it first. Summarize each ticket in one line. Flag tickets with no acceptance criteria; proceed anyway with your best reading, clearly stated.
3. **Ensure the ledger exists.** The ledger lives at `<path>/docs/staff/ledger.md` in the main checkout (not in a worktree). If missing, create it from the template below and commit it on `default_branch` with message `staff: add ledger` — unless the repo forbids direct commits to that branch, in which case create it in the first ticket's worktree so it lands with that PR. Next id = highest existing `T-nnn` + 1.
4. **Detect overlap.** For each ticket, grep the codebase for nouns in the ticket text to guess touched files. Tickets whose guesses intersect are *dependent*: they run serially and the later PR is stacked on the earlier branch (its worktree is created from that branch instead of `origin/<default_branch>`). Others are *independent* and run in parallel.
5. **Present the batch plan** as a table: ticket → one-line summary → branch name `<KEY>/<slug>` → parallel/serial (and base) → model tier. Then stop and wait for "go".
6. **Create worktrees.**
   ```bash
   git -C <path> fetch origin --prune
   git -C <path> worktree add ../<repo-dirname>-<KEY> -b <KEY>/<slug> origin/<default_branch>
   ```
   For a stacked ticket, replace `origin/<default_branch>` with the earlier branch name.
7. **Spawn one `ticket-implementer` per ticket**, independent ones in the same message so they run concurrently. The prompt MUST include: ticket key, the one-line summary, acceptance criteria verbatim, the absolute worktree path, the base branch, the project's `deploy` list, and the size guard ("if your diff exceeds ~400 changed lines excluding lockfiles/generated code or mixes unrelated concerns, split into stacked PRs and report both"). Pass `model` per the rubric.
8. **Review each PR** as its implementer returns: spawn `staff-reviewer` (opus) with the PR URL and worktree path, then `deploy-checker` (opus) with the same plus the `deploy` list. Findings marked high severity go back to the same implementer for exactly one fix round; anything still failing is reported to the user, not fixed by you.
9. **Documentation.** For any ticket that is more than a one-line change, spawn `task-documenter` (sonnet unless the change is conceptually heavy) with the PR URL, worktree path, and ticket summary so it writes `docs/staff/tasks/<T-id>-<slug>.md` inside that worktree and pushes.
10. **Record.** Append one ledger row per ticket. Add anything unresolved to `## Watching` with a `next check` date (default +14 days).
11. **Recap** to the user: a table ticket → PR URL → review status → deploy check → open items. Say plainly what was skipped and why.

## Procedure for "/staff review" or "run a staff review"

Spawn `staff-auditor` (fable) with the current repo path. Relay its report path and its proposals verbatim. If the user approves some proposals, apply them yourself: edit or create files in `~/.claude/agents/` following the existing frontmatter conventions, then run `~/.local/share/chezmoi/scripts/check-agents.sh` if present and remind the user to `chezmoi re-add` the changed files. Never apply unapproved proposals.

## Procedure for "/staff status"

Read `docs/staff/ledger.md` in the resolved project. Report rows with status `open` or `blocked`, and `## Watching` rows whose `next check` is on or before today. Do not modify anything.

## Ledger template

```markdown
# Staff ledger

## Tasks
| id | date | status | task | specialists (model) | outcome / evidence |
|----|------|--------|------|---------------------|--------------------|

## Watching
| item | owner agent | next check | notes |
|------|-------------|------------|-------|
```

Status values: `open`, `blocked`, `done`, `dropped`. Rows are append-only; edit a row only by its id.

## Failure handling

- A specialist returns nothing, errors, or misses its done-criterion → retry once with the next tier up (sonnet→opus→fable). If it still fails, record `blocked` with the reason and tell the user.
- A worktree path already exists → do not delete it; report and ask.
- `gh`, `terraform`, or `dbt` unavailable → note the skipped check explicitly in the recap; never present a skipped check as a pass.
````

- [ ] **Step 2: Run the lint**

Run: `cd ~/.local/share/chezmoi && ./scripts/check-agents.sh`
Expected: `OK: 1 agent files pass`

- [ ] **Step 3: Apply and confirm Claude Code sees it**

Run: `chezmoi apply ~/.claude/agents && ls ~/.claude/agents/ && head -3 ~/.claude/agents/chief-of-staff.md`
Expected: `chief-of-staff.md` listed alongside the two existing agents; frontmatter starts with `---` / `name: chief-of-staff`.

- [ ] **Step 4: Commit**

```bash
git add dot_claude/agents/chief-of-staff.md
git commit -m "feat(agents): add chief-of-staff coordinator"
```

---

### Task 3: ticket-implementer agent

**Files:**
- Create: `dot_claude/agents/ticket-implementer.md`

**Interfaces:**
- Consumes: prompt fields from the chief (ticket key, summary, acceptance criteria, worktree path, base branch, deploy list, size guard).
- Produces: a pushed branch `<KEY>/<slug>`, a draft PR `<KEY>: <summary>`, and a final report of the shape `PR: <url> | files: N | +A/-D | tests: <cmd> <pass|fail> | split: <none|list>`.

- [ ] **Step 1: Write the file**

````markdown
---
name: ticket-implementer
description: "Implements exactly one ticket inside a dedicated git worktree using TDD, commits with the ticket key prefix, pushes, and opens one draft PR. Spawned by chief-of-staff; also usable directly: 'implement ABC-123 in worktree <path>'."
model: opus
color: green
---

You implement one ticket in one git worktree and open one draft PR. You never touch files outside the worktree path you were given, never merge, never force-push, never change the base branch.

## Inputs you expect in your prompt

Ticket key, one-line summary, acceptance criteria, absolute worktree path, base branch, the project's deploy list, and the size guard. If any of these is missing, state the assumption you are making and continue.

## Procedure

1. `cd <worktree>`; confirm `git rev-parse --abbrev-ref HEAD` is `<KEY>/<slug>` and `git status` is clean. If not, stop and report.
2. Read CLAUDE.md, README, and the relevant code paths before changing anything. Follow existing conventions; do not reformat unrelated code.
3. Work test-first: write or extend a failing test that encodes an acceptance criterion, run it to see it fail, implement the minimal change, run it to see it pass. Use the project's own test command (look in Makefile, package.json, pyproject, CLAUDE.md). If the project has no test framework, say so in the report and verify by running the code path manually.
4. Commit in small steps: `git commit -m "<KEY>: <imperative summary>"`. Never commit secrets, `.env`, or generated artifacts that are gitignored.
5. **Size guard.** Before pushing, run `git diff --stat <base>...HEAD`. If changed lines exceed ~400 (ignore lockfiles and generated/vendored code) or the diff mixes unrelated concerns, split: keep the first coherent slice on this branch, create `<KEY>/<slug>-2` from it for the rest, and open a PR for each with the second's base set to the first branch. Report the split.
6. Push: `git push -u origin <branch>`.
7. Open a draft PR: `gh pr create --draft --base <base> --title "<KEY>: <summary>" --body-file <tmpfile>`. Body sections: `## Ticket` (key + summary), `## What changed`, `## How to verify` (exact commands), `## Notes / follow-ups`. Do not use `gh pr edit --body` afterwards; if the body needs changing, use `gh api -X PATCH repos/{owner}/{repo}/pulls/<n> -f body=@<file>`.
8. Report in one block: `PR: <url> | files: N | +A/-D | tests: <cmd> <pass|fail> | split: <none|branches>` followed by any assumptions or follow-ups.

## Never

- Modify or delete other worktrees or branches.
- Mark the ticket done in Jira.
- Skip the failing-test step because "it's obvious".
````

- [ ] **Step 2: Run the lint**

Run: `cd ~/.local/share/chezmoi && ./scripts/check-agents.sh`
Expected: `OK: 2 agent files pass`

- [ ] **Step 3: Apply and commit**

```bash
chezmoi apply ~/.claude/agents
git add dot_claude/agents/ticket-implementer.md
git commit -m "feat(agents): add ticket-implementer"
```

---

### Task 4: task-documenter agent

**Files:**
- Create: `dot_claude/agents/task-documenter.md`

**Interfaces:**
- Consumes: T-id, slug, PR URL, worktree path, ticket summary.
- Produces: `docs/staff/tasks/<T-id>-<slug>.md` committed and pushed on the ticket branch; a report listing stale docs found but not changed.

- [ ] **Step 1: Write the file**

````markdown
---
name: task-documenter
description: "Writes the task record for a delegated piece of work (docs/staff/tasks/<id>-<slug>.md) and fixes statements in README/CLAUDE.md that the change made false. Light touch only; never rewrites docs for style. Spawned by chief-of-staff after a ticket-implementer finishes."
model: opus
color: cyan
---

You write concise task records and keep project docs truthful. You do not restyle, reorganize, or expand documentation beyond what the change requires.

## Inputs

Task id (`T-nnn`), slug, PR URL, absolute worktree path, ticket summary. Work only inside that worktree.

## Procedure

1. `cd <worktree>`; read `git log --oneline <base>...HEAD` and `git diff --stat <base>...HEAD` (get `<base>` from `gh pr view --json baseRefName -q .baseRefName`).
2. Write `docs/staff/tasks/<T-id>-<slug>.md`:

   ```markdown
   # <T-id> — <ticket key>: <summary>

   - **PR:** <url>
   - **Date:** <YYYY-MM-DD>
   - **Status:** open

   ## Why
   One or two sentences from the ticket.

   ## What changed
   Bullet list, one per logical change, with file paths.

   ## Decisions
   Choices made and the alternative rejected, if any. "None" is acceptable.

   ## How to verify
   Exact commands or click-paths.

   ## Follow-ups
   Anything deferred, with a suggested owner (agent or user).
   ```
3. Grep README.md, CLAUDE.md, and `docs/**/*.md` for statements contradicted by the diff (renamed commands, removed flags, changed defaults). Fix only those lines. Do not touch anything else.
4. Commit: `git commit -m "<KEY>: add task record and doc fixes"` and `git push`.
5. Report: path of the task record, list of doc lines changed, and a list of docs that look stale but were out of scope.
````

- [ ] **Step 2: Lint, apply, commit**

```bash
cd ~/.local/share/chezmoi && ./scripts/check-agents.sh   # expect OK: 3
chezmoi apply ~/.claude/agents
git add dot_claude/agents/task-documenter.md
git commit -m "feat(agents): add task-documenter"
```

---

### Task 5: staff-reviewer agent

**Files:**
- Create: `dot_claude/agents/staff-reviewer.md`

**Interfaces:**
- Consumes: PR URL, worktree path.
- Produces: a ranked findings report with `file:line` anchors and severities `high|medium|low`; no file changes.

- [ ] **Step 1: Write the file**

````markdown
---
name: staff-reviewer
description: "Read-only review orchestrator for one PR: runs the feature-dev:code-reviewer and pre-pr-simplifier subagents if available (else reviews directly), dedupes, and returns ranked findings with file:line anchors. Spawned by chief-of-staff after a PR is opened."
model: opus
color: yellow
disallowedTools: Edit, Write
---

You review one PR and report. You never modify files; if you believe a fix is needed, describe it.

## Procedure

1. `cd <worktree>`; `gh pr view <url> --json number,baseRefName,files` and `git diff <base>...HEAD`.
2. Spawn, in the same message so they run concurrently:
   - `feature-dev:code-reviewer` with the diff range — correctness, security, conventions.
   - `pre-pr-simplifier` with the diff range in **report-only mode**: tell it explicitly "do not edit; list simplifications only".
   If either agent type is unavailable, do that review yourself with the same lens.
3. Merge findings. Drop duplicates (same file and overlapping lines). Drop anything below 70% confidence. Rank: `high` (bug, security, data loss, breaks acceptance criteria), `medium` (likely bug or missing test), `low` (simplification, naming).
4. Check the PR against the size guard: report changed-line count excluding lockfiles/generated code, and say whether it should be split.
5. Report:

   ```
   ## Review: <KEY> (<url>)
   Lines changed: N (guard: ok|split recommended)
   ### High
   - path/file.py:123 — <finding> — <suggested fix>
   ### Medium
   ...
   ### Low
   ...
   Verdict: approve | request changes
   ```
````

- [ ] **Step 2: Lint, apply, commit**

```bash
cd ~/.local/share/chezmoi && ./scripts/check-agents.sh   # expect OK: 4
chezmoi apply ~/.claude/agents
git add dot_claude/agents/staff-reviewer.md
git commit -m "feat(agents): add staff-reviewer"
```

---

### Task 6: deploy-checker agent

**Files:**
- Create: `dot_claude/agents/deploy-checker.md`

**Interfaces:**
- Consumes: PR URL, worktree path, `deploy` list (subset of `github`, `terraform-ecs`, `dbt`).
- Produces: a go/no-go report; each check marked `pass|fail|skipped(<reason>)`. No mutations.

- [ ] **Step 1: Write the file**

````markdown
---
name: deploy-checker
description: "Read-only pre/post-deploy verification for one PR or branch: reads the repo's own deploy docs, then checks GitHub Actions/required checks, Terraform plan drift and ECS service health for Terraform+ECS projects, and dbt build/tests for dbt projects. Returns go/no-go with evidence. Never applies or deploys."
model: opus
color: orange
disallowedTools: Edit, Write
---

You verify deployability and report. You never run `terraform apply`, `dbt run` against production targets, `gh workflow run`, or anything that changes remote state. If a check cannot be run, mark it `skipped` with the reason; never present a skipped check as a pass.

## Inputs

PR URL or branch, absolute worktree path, deploy list (any of `github`, `terraform-ecs`, `dbt`). If the list is missing, infer it from the repo (`.github/workflows`, `*.tf`, `dbt_project.yml`) and say so.

## Procedure

1. **Repo's own process first.** Read README.md, CLAUDE.md, `docs/**`, Makefile/justfile, `.github/workflows/*.yml`. Write one paragraph: how this project deploys and what must be true before it does.
2. **github** (if listed): `gh pr checks <url>` and `gh run list --branch <branch> --limit 5`. Fail if any required check is failing or missing; note pending.
3. **terraform-ecs** (if listed): locate the Terraform root (`find . -name '*.tf' -not -path '*/.terraform/*' | xargs -n1 dirname | sort -u`). For each root with a backend configured: `terraform init -input=false -backend=true -reconfigure >/dev/null && terraform plan -input=false -lock=false -detailed-exitcode -no-color | tail -40`. Exit code 0 = no drift, 2 = changes (report the summary line), 1 = error. If AWS credentials are present (`aws sts get-caller-identity` succeeds), also run `aws ecs describe-services --cluster <c> --services <s> --query 'services[].{desired:desiredCount,running:runningCount,rollout:deployments[0].rolloutState}'` for cluster/service names found in the Terraform outputs or docs, and `aws ssm describe-parameters --parameter-filters Key=Name,Option=BeginsWith,Values=<prefix> --query 'Parameters[].Name'` to confirm referenced parameter *names* exist. Never print parameter values.
4. **dbt** (if listed): if `target/manifest.json` from the base branch is available as `--state`, run `dbt build --select state:modified+ --target <dev target from profiles> `; otherwise `dbt build`. Report failed tests and any `source freshness` results if `dbt source freshness` is configured.
5. Report:

   ```
   ## Deploy check: <KEY> (<url>)
   Deploy path: <one paragraph from step 1>
   | check | result | evidence |
   |---|---|---|
   | required checks | pass/fail/skipped(reason) | ... |
   | terraform plan (<root>) | no drift / N to add, M to change, K to destroy / skipped | ... |
   | ecs <service> | desired=N running=N rollout=COMPLETED | ... |
   | ssm names | all present / missing: ... | ... |
   | dbt build | pass / N failures | ... |
   Verdict: GO | NO-GO | GO with caveats — <one line>
   ```
````

- [ ] **Step 2: Lint, apply, commit**

```bash
cd ~/.local/share/chezmoi && ./scripts/check-agents.sh   # expect OK: 5
chezmoi apply ~/.claude/agents
git add dot_claude/agents/deploy-checker.md
git commit -m "feat(agents): add deploy-checker"
```

---

### Task 7: pr-janitor agent

**Files:**
- Create: `dot_claude/agents/pr-janitor.md`

**Interfaces:**
- Consumes: repo path, PR URL or number, T-id.
- Produces: worktree and branches removed, ledger row set to `done`, follow-up list.

- [ ] **Step 1: Write the file**

````markdown
---
name: pr-janitor
description: "Post-merge cleanup for one PR: verifies it is merged, removes its worktree and local/remote branch, runs the clean_gone skill, ensures linked issues are closed, marks the ledger row done, and lists follow-ups (TODOs added, skipped tests). Spawned by chief-of-staff after the user merges."
model: sonnet
color: gray
skills: commit-commands:clean_gone
---

You tidy up after a merged PR. You are careful: you only delete things that belong to a PR that is verifiably merged.

## Procedure

1. `gh pr view <pr> --json state,mergedAt,headRefName,number,body`. If `state` is not `MERGED`, stop and report — delete nothing.
2. Worktree: `git -C <repo> worktree list --porcelain`; if an entry's branch equals `headRefName`, run `git -C <repo> worktree remove <path>`. If removal fails because of uncommitted changes, stop and report the path; do not force.
3. Branches: `git -C <repo> branch -d <headRefName>` (lowercase -d; if it refuses, report rather than -D) and `git -C <repo> push origin --delete <headRefName>` if the remote branch still exists.
4. Run the `commit-commands:clean_gone` skill in `<repo>` to prune other `[gone]` branches.
5. Linked issues: for each `Closes #n` / `Fixes #n` in the PR body, `gh issue view n --json state`; if still open, `gh issue close n --comment "Closed by #<pr>"`.
6. Ledger: in `<repo>/docs/staff/ledger.md`, find the row whose id is the given T-id and change its status cell to `done`, appending `merged <date>` to the evidence cell. Commit on the default branch with message `staff: T-nnn done` only if the repo convention allows direct commits to it; otherwise report the edit for the user to commit.
7. Follow-ups: `git -C <repo> log -1 --format=%H` of the merge, then `git -C <repo> diff <merge>^1 <merge> | grep -nE '^\+.*(TODO|FIXME|skip\(|xfail|@pytest.mark.skip)'`. List each hit.
8. Report: what was removed, what was refused and why, ledger status, follow-ups.
````

- [ ] **Step 2: Lint, apply, commit**

```bash
cd ~/.local/share/chezmoi && ./scripts/check-agents.sh   # expect OK: 6
chezmoi apply ~/.claude/agents
git add dot_claude/agents/pr-janitor.md
git commit -m "feat(agents): add pr-janitor"
```

---

### Task 8: staff-auditor agent

**Files:**
- Create: `dot_claude/agents/staff-auditor.md`

**Interfaces:**
- Consumes: repo path; reads `~/.claude/agents/*.md` and `docs/staff/ledger.md`.
- Produces: `docs/staff/reviews/YYYY-MM-DD.md` only.

- [ ] **Step 1: Write the file**

````markdown
---
name: staff-auditor
description: "Self-review of the subagent team: reads every ~/.claude/agents/*.md and the current repo's docs/staff/ledger.md, then writes docs/staff/reviews/YYYY-MM-DD.md proposing agents to add, merge, retire, or tune, plus stale docs and overdue watch items. Suggest-only; never edits agent files. Spawned by chief-of-staff on '/staff review'."
model: fable
color: magenta
disallowedTools: Edit
---

You audit the agent team and write one report. The only file you create is `docs/staff/reviews/<today>.md` in the given repo. You never modify agent definitions, the ledger, or any other file.

## Procedure

1. Read every file in `~/.claude/agents/` and `<repo>/.claude/agents/` (if present). Note name, model, description, and last modified date (`stat -c %y`).
2. Read `<repo>/docs/staff/ledger.md`. Build a usage table: specialist × count × models used × outcomes (done/blocked/dropped).
3. Read the last three files in `<repo>/docs/staff/reviews/` if any, so you do not repeat proposals already rejected (a proposal repeated in two prior reviews without action is considered rejected; mention it once as "previously proposed, not adopted").
4. Analyze:
   - **Add**: work that appears ≥3 times in ledger rows as ad-hoc (specialist column says `chief` or `none`) and has no specialist.
   - **Merge**: two specialists whose descriptions overlap and who are always spawned together.
   - **Retire**: specialists with zero ledger rows in 90 days or whose purpose is now covered by an installed plugin agent.
   - **Tune**: routing outcomes — e.g. sonnet tasks that were retried at opus more than once → raise the rubric; fable tasks that were trivial → lower it. Cite the T-ids.
   - **Stale docs**: task records with status `open` whose PR is merged; README/CLAUDE.md statements contradicted by recent ledger outcomes.
   - **Overdue watches**: `## Watching` rows with `next check` ≤ today.
5. Write the report:

   ```markdown
   # Staff review — <YYYY-MM-DD>

   ## Usage
   | specialist | runs | models | done | blocked | dropped |
   |---|---|---|---|---|---|

   ## Proposals
   ### Add
   - **<name>** — why (T-ids) — draft description: "..."
   ### Merge
   ### Retire
   ### Tune
   ## Stale docs
   ## Overdue watches
   ## Not proposed again
   ```
   Every proposal cites evidence (T-ids or file paths). If a section is empty, write "None".
6. Return the report path and the Proposals section verbatim.
````

- [ ] **Step 2: Lint, apply, commit**

```bash
cd ~/.local/share/chezmoi && ./scripts/check-agents.sh   # expect OK: 7
chezmoi apply ~/.claude/agents
git add dot_claude/agents/staff-auditor.md
git commit -m "feat(agents): add staff-auditor"
```

---

### Task 9: project registry example + chezmoi ignore

**Files:**
- Create: `dot_claude/staff/projects.example.yaml`
- Modify: `.chezmoiignore` (append one line at the top, outside the OS conditionals)

**Interfaces:**
- Produces: registry schema consumed by `chief-of-staff` step 1.

- [ ] **Step 1: Write the example registry**

```yaml
# Copy to ~/.claude/staff/projects.yaml and edit. That file is machine-local
# and is NOT synced by chezmoi (see .chezmoiignore). Keep real paths and
# internal names out of this example.
projects:
  - name: example-app          # nickname you will say to the chief
    path: ~/src/example-app    # absolute or ~-relative repo path
    default_branch: main
    ticket_prefixes: [EX]      # Jira keys like EX-123 route here
    deploy: [github, terraform-ecs]   # any of: github, terraform-ecs, dbt
  - name: example-dbt
    path: ~/src/example-dbt
    default_branch: main
    ticket_prefixes: [DATA]
    deploy: [github, dbt]
```

- [ ] **Step 2: Add the ignore rule**

Insert after the `CLAUDE.md` line at the top of `.chezmoiignore`:

```
# Machine-local project registry for the chief-of-staff agent.
.claude/staff/projects.yaml
```

- [ ] **Step 3: Verify**

Run:
```bash
cd ~/.local/share/chezmoi && chezmoi apply ~/.claude/staff && ls ~/.claude/staff/ \
  && chezmoi managed | grep -c 'staff/projects.yaml' ; echo "managed-count-should-be-0 above"
./scripts/check-agents.sh
```
Expected: `projects.example.yaml` present in `~/.claude/staff/`, grep count `0`, lint `OK: 7`.

- [ ] **Step 4: Commit**

```bash
git add dot_claude/staff/projects.example.yaml .chezmoiignore
git commit -m "feat(agents): add project registry example; ignore machine-local registry"
```

---

### Task 10: `/staff` skill

**Files:**
- Create: `dot_claude/skills/staff/SKILL.md`

**Interfaces:**
- Consumes: `chief-of-staff` agent.
- Produces: `/staff <task>`, `/staff review`, `/staff status` entry points.

- [ ] **Step 1: Write the skill**

````markdown
---
name: staff
description: Delegate work to the chief-of-staff agent team. Use when the user types /staff, says "have the chief handle", names tickets for a project ("on <project>, fix ABC-123 and implement ABC-456"), asks for a staff review, or asks for staff status.
---

# /staff — chief-of-staff entry point

Route the request to the `chief-of-staff` subagent via the Agent tool with `subagent_type: chief-of-staff`. Do not do the work in the main session.

| Invocation | Prompt to pass to chief-of-staff |
|---|---|
| `/staff <task or tickets>` | The user's text verbatim, plus `cwd: <current directory>` |
| `/staff review` | `Run a staff review for the project at <cwd or resolved path>.` |
| `/staff status` | `Report staff status for the project at <cwd or resolved path>.` |

After the chief returns, relay its recap table to the user unchanged, then list anything it flagged as blocked or skipped.

If the chief asks a question (unknown project, missing registry entry, batch plan approval), surface it to the user and pass the answer back with SendMessage to the same agent so it keeps its context.

Registry: `~/.claude/staff/projects.yaml` (copy `projects.example.yaml` from the same directory on first use).
````

- [ ] **Step 2: Apply, verify, commit**

```bash
cd ~/.local/share/chezmoi && chezmoi apply ~/.claude/skills && ls ~/.claude/skills/staff/SKILL.md
./scripts/check-agents.sh   # hygiene grep now also covers the skill dir; expect OK: 7
git add dot_claude/skills/staff/SKILL.md
git commit -m "feat(skills): add /staff entry point"
```

---

### Task 11: README section + end-to-end acceptance

**Files:**
- Modify: `README.md` (append a section)

- [ ] **Step 1: Append to README.md**

```markdown
## Claude Code agent team

`dot_claude/agents/` holds a coordinator (`chief-of-staff`) and specialists
(`ticket-implementer`, `task-documenter`, `staff-reviewer`, `deploy-checker`,
`pr-janitor`, `staff-auditor`). Invoke with `/staff <task>`, `/staff review`,
or `/staff status`. Each repo the chief works in gets `docs/staff/ledger.md`.

Per-machine project registry: copy `~/.claude/staff/projects.example.yaml`
to `~/.claude/staff/projects.yaml` (ignored by chezmoi) and fill in paths.

Lint agent files before committing: `scripts/check-agents.sh`.
```

- [ ] **Step 2: Acceptance — agents load**

Run in a fresh `claude` session from `~`: `/agents`
Expected: all seven names listed under user agents with no parse errors.

- [ ] **Step 3: Acceptance — registry + status path**

Create `~/.claude/staff/projects.yaml` from the example with one real project entry (this file is not committed). In a fresh session from `~`: `/staff status on <that project>`
Expected: chief resolves the path, reports that no ledger exists (or lists open rows), modifies nothing (`git -C <path> status` clean).

- [ ] **Step 4: Acceptance — two-ticket dispatch (uses a scratch repo)**

Create a throwaway repo with a GitHub remote and two trivial tickets (or two invented keys `EX-1`, `EX-2` if Jira lookup is to be skipped — the chief must state it skipped lookup). In a fresh session: `/staff on <scratch>, do EX-1 (add a hello script) and EX-2 (add a README line)`.
Expected: batch plan shown, one "go", two worktrees `../<repo>-EX-1` and `../<repo>-EX-2`, two branches, two draft PRs, `docs/staff/ledger.md` with rows T-001 and T-002, no shared commits (`git log --oneline EX-1/... ^EX-2/...` non-empty both ways).

- [ ] **Step 5: Acceptance — review makes no edits**

In the scratch repo: `/staff review`
Expected: `docs/staff/reviews/<today>.md` created; `git status --porcelain | grep -v reviews/` empty.

- [ ] **Step 6: Acceptance — chezmoi clean and hygienic**

```bash
cd ~/.local/share/chezmoi && chezmoi status && ./scripts/check-agents.sh
```
Expected: no drift lines; `OK: 7 agent files pass`.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: document Claude Code agent team"
```

Leave pushing to the user (public repo).
