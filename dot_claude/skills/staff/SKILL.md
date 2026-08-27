---
name: staff
description: Delegate work to the chief-of-staff agent team. Use when the user types /staff, says "have the chief handle", names tickets for a project ("on <project>, fix ABC-123 and implement ABC-456"), asks for a staff review, asks for staff status, or asks for post-merge cleanup of a merged PR.
---

# /staff — chief-of-staff entry point

Route the request to the `chief-of-staff` subagent via the Agent tool with `subagent_type: chief-of-staff`. Do not do the work in the main session.

| Invocation | Prompt to pass to chief-of-staff |
|---|---|
| `/staff <task or tickets>` | The user's text verbatim, plus `cwd: <current directory>` |
| `/staff review` | `Run a staff review for the project at <cwd or resolved path>.` |
| `/staff status` | `Report staff status for the project at <cwd or resolved path>.` |
| `/staff cleanup <PR>` | `Run post-merge cleanup for <PR> in the project at <cwd or resolved path>.` |

After the chief returns, relay its recap table to the user unchanged, then list anything it flagged as blocked or skipped.

If the chief asks a question (unknown project, missing registry entry, batch plan approval), surface it to the user and pass the answer back with SendMessage to the same agent so it keeps its context.

Registry: `~/.claude/staff/projects.yaml` (copy `projects.example.yaml` from the same directory on first use).
