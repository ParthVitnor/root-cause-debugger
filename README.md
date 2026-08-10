# Root-Cause Debugger

A Claude skill that enforces a disciplined "prove it before you patch it" workflow for debugging — instead of guess-and-check fixes that patch symptoms and let the real bug resurface later.

## Installation

This is a **Claude Code skill**. To install it:

### Option 1: Global install (recommended)
```bash
# Clone or copy this directory to your Claude skills directory
cp -r root-cause-debugger ~/.claude/skills/root-cause-debugger
```

Then reload skills in your Claude Code session:
```bash
# In a Claude Code session
/skill refresh
```

### Option 2: Project-local install
```bash
# From your project root
mkdir -p .claude/skills
cp -r /path/to/root-cause-debugger .claude/skills/root-cause-debugger
```

Then use it in your project:
```bash
# In a Claude Code session within that project
/skill root-cause-debugger
```

### Prerequisites
- **Claude Code** (the CLI) — [install guide](https://docs.anthropic.com/claude-code/getting-started)
- **Git** — required for the evidence collection and bisect scripts
- **Bash** — the helper scripts (`collect-evidence.sh`, `bisect-culprit.sh`, `scan-signals.sh`) are POSIX shell scripts

### Verify installation
```bash
# Check the skill is recognized
/skill list | grep root-cause-debugger

# Or invoke it directly
/skill root-cause-debugger
```

---

## Quick Start

Once installed, invoke the skill when you hit a bug, failing test, or incident:

```bash
# In a Claude Code session
/skill root-cause-debugger
```

Then describe the problem — e.g., *"Test `test_user_login` fails intermittently with a timeout"* or *"Production error spike: 500s on `/api/checkout` since deploy abc123"*.

The skill will walk you through the 5-stage workflow, running the helper scripts as needed to collect evidence, bisect the culprit, and scan for quality signals.

---

## Why this exists

The fastest-looking fix is usually a guess dressed up as a fix. It patches the symptom, the underlying condition survives, and the same bug — or a cousin of it — resurfaces somewhere else in the codebase later. This skill's ground rule: don't write or suggest a fix until you can state the root cause in one sentence, backed by evidence you actually collected.

It applies to a single broken function just as much as a full production outage, and doesn't assume any particular language or stack.

## When it triggers

- A bug report, stack trace, exception, or crash
- A test that fails, or fails intermittently
- Behavior that "shouldn't be possible" given the code
- A production incident, error spike, or bad deploy
- "It worked before, now it doesn't"
- A request to review code for bugs, quality problems, or security holes

## The workflow

Five stages, each producing evidence the next one needs:

1. **Reproduce and capture** — get a reliable trigger, read the full error, check what changed recently.
2. **Localize** — narrow down to where the fault actually lives, not just where it surfaced.
3. **Form one hypothesis, test it alone** — change exactly one variable and see if it confirms the cause.
4. **Fix at the source, then prove it** — write a failing test first, make one root-cause change, confirm it holds.
5. **Harden and sweep** — add safeguards so the same failure can't recur elsewhere, and sweep the touched code for related quality/security issues.

If three genuine, evidence-backed fix attempts all fail, that's treated as a signal the underlying design is the real problem — not a cue to try a fourth patch.

## Project structure

```
root-cause-debugger/
├── SKILL.md                                 # Full workflow definition (entry point)
├── references/
│   ├── backward-tracing.md                  # Trace a bug backward call-by-call to its origin
│   ├── layered-safeguards.md                # Add validation at every layer, not one checkpoint
│   ├── flaky-and-race-conditions.md         # Diagnose intermittent failures and race conditions
│   ├── code-quality-and-security-pass.md    # Checklist for stage 5 sweeps
│   ├── production-incident-timeline.md      # Workflow adapted for live outages
│   └── rca-report-template.md               # Template for write-ups worth keeping
└── scripts/
    ├── collect-evidence.sh                  # Stage 1: gather repo context
    ├── bisect-culprit.sh                    # Stage 2: find the first bad commit/candidate
    └── scan-signals.sh                      # Stage 5: grep for quick quality/security signals
```

## Scripts

### `scripts/collect-evidence.sh`
Gathers stack-independent context at the start of an investigation: recent commit history, working-tree changes, and a best-effort guess at the project's language from common marker files.

```bash
./scripts/collect-evidence.sh [path-to-repo] [number-of-commits]
# defaults to the current directory and the last 15 commits
```

### `scripts/bisect-culprit.sh`
Finds the first bad candidate during localization. Two modes:

```bash
# Commit mode — wraps `git bisect` between a known-good and known-bad commit
./scripts/bisect-culprit.sh --commits <good-sha> <bad-sha> -- <check-command>

# List mode — runs a command against each item in a list, stops at the first failure
./scripts/bisect-culprit.sh --list item1 item2 item3 -- <command-with-{}>
```

### `scripts/scan-signals.sh`
Greps changed (or specified) files for quick-signal patterns from `code-quality-and-security-pass.md` — unsafe dynamic execution, command injection, insecure deserialization, hardcoded secrets, weak hashing, predictable secret generation. A hit is a signal worth a closer look, not proof of a problem.

```bash
./scripts/scan-signals.sh [--fail-on-hit] [path-or-file ...]
# with no path: scans working-tree changes inside a git repo, or the current
# directory recursively otherwise
```

## Reference docs

| File | Covers |
|---|---|
| `backward-tracing.md` | Tracing a bug backward through calls or data flow to its true origin |
| `layered-safeguards.md` | Building validation in layers so a fixed bug stays fixed |
| `flaky-and-race-conditions.md` | Handling intermittent failures and timing-dependent bugs |
| `code-quality-and-security-pass.md` | Language-agnostic quality/vulnerability checklist, plus per-language tooling |
| `production-incident-timeline.md` | Reconstructing a production or log-based incident |
| `rca-report-template.md` | Structured write-up template for incidents worth documenting |

## What gets handed back

- **A quick chat fix:** one or two sentences on the root cause, the evidence for it, and what changed.
- **Something worth a written record** (a production incident, a bug with a non-obvious cause): a full write-up using `references/rca-report-template.md`.

---

## Troubleshooting & Tips

### Skill not found after install
- Run `/skill refresh` in your Claude Code session
- Verify the directory name is exactly `root-cause-debugger` inside `~/.claude/skills/` or `.claude/skills/`
- Check `/skill list` — it should appear there

### Scripts fail with "permission denied"
```bash
chmod +x scripts/*.sh
```

### Git bisect mode needs a known-good commit
If you don't know a good commit, use list mode instead:
```bash
./scripts/bisect-culprit.sh --list <candidate1> <candidate2> ... -- <test-command>
```

### Using the scripts standalone
All scripts work independently of the skill — you can call them directly from your terminal:
```bash
# From the skill directory
./scripts/collect-evidence.sh /path/to/your/repo 20
./scripts/bisect-culprit.sh --commits abc123 def456 -- npm test
./scripts/scan-signals.sh --fail-on-hit
```

### Customizing the scan patterns
Edit `references/code-quality-and-security-pass.md` to add/remove patterns for your stack, then `scan-signals.sh` will pick them up automatically.
