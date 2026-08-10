# RCA Report Template

Use this when a debugging session is worth a written record — a production incident, a bug with a non-obvious cause, or anything a teammate will want context on later. Skip it for a routine fix; a one- or two-sentence summary in the chat or commit message is enough for those.

Fill in only the sections that apply — a local bug fix usually won't need "Impact" or "Timeline" filled with production-incident detail, for instance.

```markdown
# [Short, specific title — name the failure, not just "bug fix"]

## Summary
One or two sentences: what broke, what caused it, what fixed it. Someone should be
able to read just this section and understand the incident.

## Impact
- Who/what was affected, and how much (error rate, duration, requests, users, data)
- Was any data lost or corrupted, or was this a visible-but-recoverable failure?

## Timeline
(For production incidents — omit for a routine local bug fix)
- `HH:MM` — First error observed / alert fired
- `HH:MM` — Change identified as correlated (deploy, config, traffic shift)
- `HH:MM` — Mitigation applied (rollback / flag flip / rate limit)
- `HH:MM` — Root cause confirmed
- `HH:MM` — Permanent fix deployed
- `HH:MM` — Confirmed resolved

## Root Cause
The actual underlying cause — not the symptom. State it as a single clear claim,
the way you would have written it at the end of stage 3 of the workflow.

## Evidence
What you observed that supports the root cause above: logs, stack traces, the
specific commit/diff, the failing test, the bisection result. Enough detail that
someone else could verify your conclusion without re-doing the whole investigation.

## Fix
What actually changed, and why it addresses the root cause specifically (not just
the symptom). Link the commit/PR.

## Verification
How you confirmed the fix works: the new regression test, the metric that
recovered, the manual check performed.

## Follow-ups / Prevention
- Safeguards added (see `layered-safeguards.md`) and where
- Monitoring/alerting added, if any
- Anything found during the quality/security sweep but deliberately deferred,
  with an owner or ticket reference
- Whether this reveals a broader design issue worth a separate conversation
  (see "When three fixes fail" in the main SKILL.md)
```
