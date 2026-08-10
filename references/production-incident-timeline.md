# Production Incident Timeline

## How this differs from a local repro

Locally, you can usually reproduce a bug on demand and iterate quickly. In production, the failure already happened (or is actively happening) to real traffic, you often can't reproduce it at will, and the priority order is different: understand impact and stop the bleeding, *then* pursue the same root-cause standard as any other bug — reconstructing after the fact instead of reproducing live.

## Step 1: Establish impact before anything else

- Error rate and trend: climbing, flat, or already recovering?
- What fraction of traffic/users is actually affected — all requests, one endpoint, one region, one customer segment?
- Is data being corrupted or lost, or is this a visible-but-recoverable failure (errors shown, but no bad writes happening)? This materially changes urgency.

This isn't optional process overhead — it's what determines whether a fast, less-certain mitigation (rollback, feature flag, rate limit) is the right call before the investigation is even finished.

## Step 2: Build a timeline

Pull together, on one timeline, anchored on when the error rate first moved:
- Log entries and error spikes, with timestamps
- Deploys (what shipped, and exactly when)
- Config or feature-flag changes
- Infrastructure changes (scaling events, failover, provider incidents)
- Traffic pattern changes (a spike, a new client version rolling out, a bot/scraper surge)

The question you're answering: **what changed at or immediately before the moment things started failing?** This is the same "check recent changes" step from the main workflow — the timeline is just how you do it when you can't just run `git log` against a single known-good local state, because "known good" here means "the last few minutes of a live system," not one commit.

## Step 3: Correlate, don't just list

A deploy that happened 6 hours before the error spike is far less suspicious than one that happened 90 seconds before it. Order the timeline and look specifically at what's adjacent to the onset, not just what changed recently in general. If multiple things changed near the same time, note all of them — the actual cause isn't always the most obviously suspicious one.

## Step 4: Decide rollback vs. forward-fix

- **Rollback** when a specific deploy correlates tightly with the onset, rolling back is fast and safe for this system, and you don't yet have a confirmed root cause. Rolling back doesn't require a root cause — it's often the fastest way to stop impact while the investigation continues in parallel.
- **Forward-fix** when the root cause is identified with real confidence, the fix is small and well-understood, and a rollback is slow, unsafe (e.g., a schema migration that isn't cleanly reversible), or would revert unrelated, wanted changes along with the bad one.
- These aren't mutually exclusive with the rest of the workflow — after either one, stages 2 through 5 of the main process still apply to find and fix the actual root cause, not just the immediate trigger.

## Step 5: After impact is controlled, debug it properly

Once things are stable, this becomes an ordinary root-cause investigation using the timeline as your evidence instead of a manual repro:
- Localize using the correlated change from step 3 as your leading hypothesis, but confirm it — verify the change actually causes the symptom rather than assuming a match on timing is a match on causation.
- Form a single hypothesis, test it (in a staging environment or with production-like data, not by re-triggering the incident against real traffic if you can help it).
- Fix at the source, with a regression test that encodes the specific bad condition — not just a test that happens to catch a symptom.
- Harden and sweep per stage 5 of the main workflow.

## Step 6: Close the loop

- Add monitoring or an alert that would have caught this earlier next time, specifically targeting the actual failure mode found — not a generic "add more logging" note.
- If the write-up is worth keeping for the team, use `rca-report-template.md`, with the timeline from step 2 filling in its Timeline section directly.
