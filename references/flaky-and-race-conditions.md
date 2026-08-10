# Flaky Failures and Race Conditions

## The idea

"It passes locally but fails in CI" or "it fails about one run in ten" almost always means something is racing something else — a test asserting on state before an async operation finished, two workers writing to shared state in an order the code didn't account for, a timeout that's fine on a fast machine and too short on a loaded one. The fix is essentially never "add a longer sleep" — that just narrows the window without closing it, and the failure comes back the next time the environment is a bit slower.

**Core move:** wait for the actual condition you care about, don't guess at how long it takes to become true.

## Recognizing it

- Arbitrary delays in the code: `sleep(50)`, `setTimeout(..., 200)`, `time.sleep(0.1)`, used as a stand-in for "should be done by now"
- Tests that pass alone but fail when run in parallel or under load
- Failures that disappear when you add logging or run it in a debugger (a strong sign of a genuine timing dependency, not a red herring)
- Shared mutable state (a global, a shared file, a database row) touched by more than one concurrent path without coordination

## The pattern, generalized

```
# BEFORE — guessing at timing
sleep(50ms)
result = getResult()
assert result is not None

# AFTER — waiting for the actual condition
result = waitFor(lambda: getResult(), timeout=5000ms)
assert result is not None
```

A generic polling helper, language-agnostic in shape:

```
function waitFor(condition, timeoutMs = 5000, pollIntervalMs = 10):
    startTime = now()
    loop:
        result = condition()
        if result:
            return result
        if now() - startTime > timeoutMs:
            raise TimeoutError("condition not met within " + timeoutMs + "ms")
        sleep(pollIntervalMs)
```

Common instantiations:

| Waiting for | Condition |
|---|---|
| An event to fire | `events.any(e => e.type == "DONE")` |
| A state transition | `machine.state == "ready"` |
| A count to be reached | `queue.length >= expected` |
| A file to appear | `fileExists(path)` |
| A combination of conditions | `obj.ready and obj.value > threshold` |

## Mistakes to avoid

- **Polling too aggressively** (every 1ms) burns CPU for no benefit — 10–50ms is usually plenty.
- **No timeout at all** turns a flaky failure into a hang — always bound the wait and raise a clear error naming what it was waiting for.
- **Reading stale state** — make sure `condition()` re-fetches live state each iteration rather than closing over a value captured once before the loop started.

## When an arbitrary delay is actually correct

Sometimes you're deliberately testing timing behavior itself — a debounce, a throttle, a scheduled retry interval. In that case a fixed delay is appropriate, but it should still be justified, not guessed:

```
waitForEvent(manager, "STARTED")      # first: wait for the real trigger condition
sleep(200ms)                          # then: a *documented*, known interval —
                                       # e.g. "2 ticks at a 100ms poll interval" — not a guess
```

The distinguishing question: are you waiting for something to *finish*, or specifically testing *how long* something takes? Only the second case justifies a fixed sleep, and even then it should be commented with the reasoning, not left as a bare number.

## Beyond tests: race conditions in running systems

The same root idea shows up outside test suites, in concurrent production code:
- Two requests read-modify-write the same record without locking, and the second write clobbers the first (classic lost-update)
- A resource is checked for existence and then used in two separate steps, with another process able to act in between (check-then-act race)
- Initialization order is assumed but not enforced — code reads a value before whatever sets it up has necessarily run

For these, the fix isn't a polling loop, it's usually one of: a lock/mutex around the critical section, an atomic compare-and-swap instead of separate check-then-act steps, or restructuring so the ordering dependency doesn't exist in the first place. The diagnostic approach from the main workflow still applies — reproduce it (running the operation concurrently under load is often the only reliable repro), trace which two operations are actually interleaving, and fix the ordering assumption at its source rather than adding a delay that only makes the race less likely to be hit.
