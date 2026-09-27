# Root-Cause Debugger

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Claude skill that enforces a disciplined "prove it before you patch it" workflow for debugging — instead of guess-and-check fixes that patch symptoms and let the real bug resurface later.

**Repository:** https://github.com/ParthVitnor/root-cause-debugger

---

## Installation

### Quick Install (Recommended)

Install the skill globally with a single command:

```bash
claude skill install https://github.com/ParthVitnor/root-cause-debugger
```

That's it! The skill is now available in all your Claude Code sessions.

### Manual Install

If you prefer manual installation:

```bash
# Clone the repository
git clone https://github.com/ParthVitnor/root-cause-debugger.git

# Copy to your Claude skills directory
cp -r root-cause-debugger ~/.claude/skills/root-cause-debugger
```

Then reload skills:
```bash
# In a Claude Code session
/skill refresh
```

### Verify Installation

```bash
# Check the skill is recognized
/skill list | grep root-cause-debugger
```

### Prerequisites

- **Claude Code CLI** — [Install Guide](https://docs.anthropic.com/claude-code/getting-started)
- **Git** — Required for evidence collection and bisect scripts
- **Bash** — The helper scripts are POSIX shell scripts

---

## Quick Start

Once installed, invoke the skill when debugging:

```bash
# In a Claude Code session
/skill root-cause-debugger
```

Then describe your problem:
- *"Test `test_user_login` fails intermittently with a timeout"*
- *"error spike: 500s on `/api/checkout` since deploy abc123"*
- *"Getting this stack trace when I run `npm test`"*

The skill walks you through a 5-stage workflow, running helper scripts to collect evidence, bisect culprits, and scan for quality issues.

---

## Why This Exists

The fastest-looking fix is usually a guess dressed up as a fix. It patches the symptom, the underlying condition survives, and the same bug — or a cousin of it — resurfaces later. 

**Ground rule:** Don't write or suggest a fix until you can state the root cause in one sentence, backed by evidence you actually collected — not evidence you assume must be there.

This applies to:
- A single broken function
- A failing test
- A full outage
- Any language or stack

---

## When to Use

Reach for this skill when you encounter:

- A bug report, stack trace, exception, or crash
- A test that fails, or fails intermittently
- Behavior that "shouldn't be possible" given the code
- A production incident, error spike, or bad deploy
- "It worked before, now it doesn't"
- A request to review code for bugs, quality problems, or security holes

Use it especially when it's tempting to skip investigation:
- Something is on fire and everyone wants a fix *now*
- The fix "obviously" is X — a one-liner, low risk, why not just try it
- You've already tried two fixes and neither stuck
- You don't actually understand why it's broken yet, but you have a guess

---

## The Workflow

Five stages. Each produces evidence the next one needs — don't skip ahead.

### 1. Reproduce and Capture

You can't fix what you can't observe.

- Get a reliable trigger: the exact input, command, or sequence that causes the failure
- Read the *entire* error: full stack trace, exit codes, every line of logs
- Check what changed recently: `git log`, `git diff`, recent dependency bumps, config changes
- If the failure crosses boundaries (service to service, function to function), add logging at each boundary

### 2. Localize

Narrow down to where the fault actually lives — not where it surfaced.

- Find a working comparison: something similar that *doesn't* fail
- Trace backward call by call until you find where the bad value originated
- Use `git bisect` or the included `bisect-culprit.sh` script

### 3. Form One Hypothesis, Test It Alone

- Write down: "I believe X is the cause, because evidence Y shows Z"
- Make the smallest possible change to confirm or kill that hypothesis
- Change exactly one variable

### 4. Fix at the Source, Then Prove It

- Write a test that fails *because of* the root cause
- Make one change that addresses the cause
- Confirm: new test passes, existing tests pass, original symptom is gone

### 5. Harden and Sweep

- Add safeguards at boundaries, not just at the crash point
- Sweep the touched code for related quality and security issues
- Use the included `scan-signals.sh` script

**If three evidence-backed fix attempts fail, the underlying design is likely the problem — stop patching and raise it as a design question.**

---

## Project Structure

```
root-cause-debugger/
├── SKILL.md                                 # Full workflow definition (entry point)
├── README.md                                # This file
├── LICENSE                                  # MIT License
├── references/
│   ├── backward-tracing.md                  # Trace bugs backward to their origin
│   ├── layered-safeguards.md                # Validation at every layer
│   ├── flaky-and-race-conditions.md         # Diagnose intermittent failures
│   ├── code-quality-and-security-pass.md    # Stage 5 quality/security checklist
│   ├── production-incident-timeline.md      # Workflow for live outages
│   └── rca-report-template.md               # Template for incident write-ups
└── scripts/
    ├── collect-evidence.sh                  # Gather repo context
    ├── bisect-culprit.sh                    # Find first bad commit/candidate
    └── scan-signals.sh                      # Grep for quality/security signals
```

---

## Scripts

### collect-evidence.sh

Gathers stack-independent context: recent commits, working-tree changes, project language detection.

```bash
./scripts/collect-evidence.sh [path] [commit-count]
# Defaults to current directory, last 15 commits
```

### bisect-culprit.sh

Finds the first bad candidate during localization.

```bash
# Commit mode — wraps git bisect
./scripts/bisect-culprit.sh --commits <good-sha> <bad-sha> -- <check-command>

# List mode — test multiple candidates
./scripts/bisect-culprit.sh --list item1 item2 item3 -- <command-with-{}>
```

### scan-signals.sh

Greps for quick-signal patterns: unsafe dynamic execution, command injection, hardcoded secrets, weak hashing.

```bash
./scripts/scan-signals.sh [--fail-on-hit] [path-or-file ...]
# No path: scans git changes or current directory
```

---

## Reference Documentation

| Document | Purpose |
|----------|---------|
| `backward-tracing.md` | Trace bugs backward through calls/data flow |
| `layered-safeguards.md` | Build validation in layers |
| `flaky-and-race-conditions.md` | Handle intermittent failures |
| `code-quality-and-security-pass.md` | Quality/vulnerability checklist |
| `production-incident-timeline.md` | Reconstruct production incidents |
| `rca-report-template.md` | Structured incident write-up template |

---

## What You Get Back

- **Quick fix:** One or two sentences on root cause, evidence, and what changed
- **Significant issue:** Full write-up using the RCA report template

---

## Troubleshooting

### Skill not found after install

```bash
/skill refresh
```

Verify the directory is exactly `root-cause-debugger` inside `~/.claude/skills/`

### Scripts fail with "permission denied"

```bash
chmod +x scripts/*.sh
```

### Git bisect needs a known-good commit

Use list mode instead:

```bash
./scripts/bisect-culprit.sh --list <candidate1> <candidate2> ... -- <test-command>
```

---

## Contributing

Found a bug or have an improvement? Open an issue or submit a pull request at:

https://github.com/ParthVitnor/root-cause-debugger

---

## License

MIT License — see [LICENSE](LICENSE) for details.
