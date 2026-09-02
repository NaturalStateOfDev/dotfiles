---
name: alfred
description: Delegate work to the alfred agent team. Use when the user types /alfred or /staff, says "have Alfred handle", "ask Alfred", or "have the chief handle", names tickets for a project ("on <project>, fix ABC-123 and implement ABC-456"), asks for a staff review, asks for staff status, or asks for post-merge cleanup of a merged PR.
---

# /alfred — Alfred entry point (also reachable as /staff)

Route the request to the `alfred` subagent via the Agent tool with `subagent_type: alfred`. Do not do the work in the main session.

| Invocation | Prompt to pass to Alfred |
|---|---|
| `/alfred <task or tickets>` | The user's text verbatim, plus `cwd: <current directory>` |
| `/alfred review` | `Run a staff review for the project at <cwd or resolved path>.` |
| `/alfred status` | `Report staff status for the project at <cwd or resolved path>.` |
| `/alfred cleanup <PR>` | `Run post-merge cleanup for <PR> in the project at <cwd or resolved path>.` |

After Alfred returns, relay its recap table and its Jira hygiene table to the user unchanged, then list anything it flagged as blocked, skipped, or untracked.

If Alfred asks a question (unknown project, missing registry entry, batch plan approval), surface it to the user and pass the answer back with SendMessage to the same agent so it keeps its context.

Registry: `~/.claude/staff/projects.yaml` (copy `projects.example.yaml` from the same directory on first use).
