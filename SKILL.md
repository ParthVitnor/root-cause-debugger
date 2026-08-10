---
name: root-cause-debugger
description: "Use this whenever the user is debugging any codebase — an error, exception, crash, failing or flaky test, unexpected output, a production incident, or a pasted stack trace/log — no matter the programming language or stack. Drives a disciplined \"prove it before you patch it\" workflow instead of guess-and-check: reproduce, gather evidence, trace back to the true origin, test one hypothesis at a time, fix at the source, verify, then sweep the touched code for related quality and security issues. Trigger this for phrases like \"why is this breaking\", \"getting this error\", \"test keeps failing\", \"it worked yesterday\", \"production is down\", \"can you find the bug\", or whenever the user pastes an error message, traceback, or log snippet — even if they never say the word \"debug\". Also use it when asked to review a codebase for bugs, code quality, or vulnerabilities."
---

# Root-Cause Debugger

## Why this exists

The fastest-looking fix is usually a guess dressed up as a fix. It patches the symptom, the underlying condition survives, and the same bug — or a cousin of it — resurfaces somewhere else in the codebase later. The way out isn't to work faster, it's to work in order: understand the failure completely before touching the code that's supposed to fix it.

**Ground rule:** don't write or suggest a fix until you can state the root cause in one sentence, backed by evidence you actually collected — not evidence you assume must be there.

This applies to a broken function just as much as a production outage. The investigation techniques below flex to fit the situation; the ground rule doesn't move.

## When to reach for this

Any of:
- A bug report, stack trace, exception, or crash
- A test that fails, or fails intermittently
- Behavior that "shouldn't be possible" given the code
- A production incident, error spike, or bad deploy
- "It worked before, now it doesn't"
- A request to review code for bugs, quality problems, or security holes

Reach for it hardest exactly when it's tempting to skip:
- Something is on fire and everyone wants a fix *now*
- The fix "obviously" is X — a one-liner, low risk, why not just try it
- You've already tried two fixes and neither stuck
- You don't actually understand why it's broken yet, but you have a guess

None of these are reasons to skip investigation. Under real time pressure, thrashing through unverified fixes usually costs more time than the investigation would have — a wrong guess shipped under pressure tends to create a second incident on top of the first.

## The workflow

Five stages. Each one produces evidence the next stage needs — don't skip ahead on a hunch.

### 1. Reproduce and capture

You can't fix what you can't observe.

- Get a reliable trigger: the exact input, command, request, or sequence of steps that causes it. "Sometimes it happens" isn't a repro yet — narrow it until you have a specific condition, or until you've confirmed it's genuinely non-deterministic (see `references/flaky-and-race-conditions.md`).
- Read the *entire* error, not just the first line: the full stack trace, exit codes, every line of a multi-line log entry. The detail that seems irrelevant is frequently the one that matters.
- Check what changed recently: `git log`, `git diff` against the last known-good state, recent dependency bumps, config or environment changes, infra changes. Bugs overwhelmingly correlate with *something* that changed — find the something before guessing at causes.
- If the failure crosses a boundary — service to service, process to process, function to function, CI step to CI step — add logging or print statements at each boundary and run it once to see exactly where good data turns into bad data, rather than trying to reason about it from the code alone.

For a log-driven or production issue, see `references/production-incident-timeline.md` — the evidence you need, and the order you gather it in, is a little different when you're reconstructing an incident after the fact rather than reproducing a bug locally.

### 2. Localize

Evidence in hand, narrow down to where the fault actually lives — not where it happened to surface.

- Find a working comparison: something similar in the same codebase that *doesn't* fail. Line the two up and list every difference. Don't dismiss any of them as "can't matter" before checking.
- If the failure surfaces several calls away from where it was introduced — a bad value created in one place, only exploding three layers later — trace it backward call by call until you reach the place it actually originated. Full technique in `references/backward-tracing.md`.
- If you can't reason your way there, bisect: `git bisect`, or run the failing case against successive commits, inputs, or configs until you find the exact one that flips it from passing to failing. `scripts/bisect-culprit.sh` automates the "run this check against a list of candidates and stop at the first failure" part.

### 3. Form one hypothesis, test it alone

- Write down, in one sentence: "I believe X is the cause, because evidence Y shows Z." If you can't fill that in with something concrete, you're not ready for this stage — go back to stage 1 or 2.
- Make the smallest possible change that would confirm or kill that hypothesis. Change exactly one variable.
- If it's confirmed, move to stage 4. If not, that's real information — write down what you now know and form a new hypothesis. Don't layer a second speculative change on top of the first; you'll no longer know which one did anything.
- If you genuinely don't understand what's happening, say that plainly rather than shipping a change you can't explain. Guessing your way to a passing test produces fixes that don't survive the next edge case.

### 4. Fix at the source, then prove it

- Before changing the fix code, write a test (or a minimal repro script, if there's no test framework in play) that fails *because of* the root cause you found. If it doesn't fail before your fix, it isn't testing the bug.
- Make one change that addresses the cause identified in stage 3 — not a bundle of "while I'm in here" cleanups. Those belong in a separate change so they can be reviewed and reverted independently.
- Confirm: the new test passes, the rest of the suite still passes, and the original symptom is actually gone — not just quieter.
- If the fix doesn't hold, stop. Don't reach for fix attempt number two immediately — go back to stage 1 with what you just learned. If this is your third failed attempt at the same bug, that's a different problem — see below.

### 5. Harden and sweep

A root-cause fix earns a little more scrutiny of the neighborhood it came from, not just the one line that changed:

- **Add a safeguard, not just a patch.** If the value that broke things could plausibly go wrong the same way somewhere else, add validation at the boundary where bad data enters, not only at the point it happened to crash. `references/layered-safeguards.md` covers building this in layers so a missed check in one place doesn't reopen the bug.
- **Sweep the touched area for quality and security issues while you're already in there.** You have context on this code right now that you won't have later — use it. `references/code-quality-and-security-pass.md` has a language-agnostic checklist: unsafe input handling, hardcoded secrets, missing error handling, risky dynamic execution, dependencies with known CVEs, plus the more ordinary code-smell issues (dead code, unclear naming, functions doing too much). `scripts/scan-signals.sh` automates the checklist's grep-able signals (defaults to just the files you changed) so you're not retyping the same patterns by hand each time — run it, then read every hit yourself; it flags things worth a look, not confirmed problems.
- Note anything you find but decide not to fix right now — flag it rather than silently walking past it.

## When three fixes fail

If you've made three genuine, evidence-backed attempts at the same bug and none of them held, the pattern itself is telling you something: this usually isn't "try a fourth fix," it's "the design underneath this code is the actual problem." Each attempt revealing a *new* failure in a *different* place is the tell. Stop patching and raise it as a design question with whoever owns the code, rather than attempting a fourth quick fix.

## Signs you're about to skip a step

Catch yourself, then go back to the stage you skipped:

- "I'll fix this and investigate properly later" — later rarely comes, and now there are two problems.
- "It's probably X, let me just try that" — that's a hypothesis with no evidence behind it yet.
- "I already sort of see the problem" — seeing a symptom isn't the same as knowing the cause.
- "I'll change a few things and see what sticks" — you won't be able to tell which change mattered.
- "The test is annoying, I'll verify manually" — manual verification doesn't survive the next regression.
- "One more attempt" (after two failed ones) — see the section above.
- "It's just a lint warning, the scanner's probably wrong" — check before dismissing; scanners are wrong sometimes, but "probably" isn't a check.

| What it sounds like | What's actually true |
|---|---|
| "Simple bug, doesn't need the full process" | Small bugs have root causes too — the investigation is proportionally quick. |
| "No time, this is urgent" | An unverified fix under pressure risks a second incident on top of the first. |
| "Quick fix now, real fix later" | The quick fix ships. The real fix, historically, does not. |
| "Multiple changes at once, faster that way" | You lose the ability to tell which change worked, or which one broke something else. |
| "I understand the pattern well enough to skip the reference" | Partial understanding of a pattern is exactly what produces bugs that mimic it. |

## Working across languages and stacks

This process doesn't assume any particular language. A few notes on adapting it:
- "Recent changes" means whatever version control the project uses — git is typical, but the principle (diff against the last known-good state) holds regardless.
- "Add logging at the boundary" can mean `console.error`, `print`, `fmt.Println`, `System.out`, a debugger breakpoint, or a structured logger — use whatever's idiomatic and *actually visible* in that environment (test runners sometimes swallow ordinary stdout; stderr usually isn't swallowed).
- Dependency and vulnerability tooling is stack-specific — see the table in `references/code-quality-and-security-pass.md`.
- `scripts/collect-evidence.sh` gathers the generic, stack-independent context (recent commits, working-tree diff, detected project/language markers) so stage 1 doesn't start from a blank page.

## What to hand back

Match the depth of the output to the depth of the problem:
- **A quick chat fix:** one or two sentences on the root cause, the evidence for it, and what changed. No template needed.
- **Something worth a written record** — a production incident, a bug with a non-obvious cause, anything a teammate will want context on later — use `references/rca-report-template.md`.

## Reference files

- `references/backward-tracing.md` — tracing a bug backward through calls or data flow to its true origin
- `references/layered-safeguards.md` — building validation in layers so a fixed bug stays fixed
- `references/flaky-and-race-conditions.md` — handling intermittent failures and timing-dependent bugs
- `references/code-quality-and-security-pass.md` — language-agnostic quality and vulnerability checklist, plus per-language tooling
- `references/production-incident-timeline.md` — reconstructing a production or log-based incident
- `references/rca-report-template.md` — structured write-up template for incidents worth documenting
- `scripts/collect-evidence.sh` — gathers repo context (recent history, diff, detected stack) at the start of an investigation
- `scripts/bisect-culprit.sh` — runs a check against a list of candidates (commits, files, configs) and reports the first one that fails
- `scripts/scan-signals.sh` — greps changed (or specified) files for the quick-signal patterns from `code-quality-and-security-pass.md`, for stage 5
