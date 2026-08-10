# Backward Tracing

## The idea

When a failure surfaces deep inside a call chain, the natural instinct is to fix it right where it exploded. That's usually a symptom fix — the bad value or bad state was created somewhere upstream, and patching the crash site just moves the explosion to the next place that receives the same bad input.

**Core move:** start at the crash, and walk backward one caller at a time — "what handed this function the value it choked on, and where did *that* value come from?" — until you reach the place the bad value was actually created. Fix there.

## When to use it

- The error surfaces several layers away from where you'd guess the real problem is
- The stack trace is long and the top frame is a generic failure (null/undefined access, type error, out-of-range index)
- You're not sure where invalid data first entered the system
- You need to identify exactly which caller, request, or code path triggers the problem

If you can't trace backward at all — the value comes from outside your codebase entirely (user input, a third-party API, hardware) — that's your source; stop tracing and validate at that boundary instead.

## Worked example

**Symptom:** a monthly report generator throws `attribute 'total' not found on None` while formatting the summary row.

**Step 1 — immediate cause.** The formatter calls `line.total` on an object that turns out to be `None`. So somewhere, a "line" object is being created without a `total`.

**Step 2 — who built it.** The line objects come from `build_summary_lines(rows)`, which maps each raw row to a line object and sets `total = convert_to_usd(row.amount, row.currency)`.

**Step 3 — trace one level up.** `convert_to_usd` returns `None` when it doesn't recognize the currency code — it was written to fail soft rather than throw, on the assumption the caller would handle it. The caller doesn't.

**Step 4 — keep going.** Where does an unrecognized currency code come from? `row.currency` is read straight from a CSV import. Checking the actual file: one row has a trailing comma, which shifts every subsequent column over by one — the "currency" field for that row is actually the next column's data.

**Step 5 — original trigger found.** The CSV parser doesn't validate column count per row before assigning fields positionally. A single malformed row silently corrupts every field after it for that row.

**Root cause:** the parser trusts column position without checking row shape, so one malformed input row propagates a bad value through currency conversion, into a report line with no `total`, and finally crashes three functions away from where the actual defect is.

**Fix at the source:** validate row shape in the parser (reject or flag rows with the wrong column count) — not "handle `None` totals in the formatter," which would only hide the same underlying corruption next time it shows up somewhere else.

**Worth adding on top:** `convert_to_usd` failing soft (returning `None` instead of raising) is itself worth reconsidering — a loud failure at that boundary would have pointed straight at the real problem instead of surfacing three calls later. See `layered-safeguards.md`.

## When you can't trace by reading alone

Add instrumentation and run it once rather than trying to hold the whole call chain in your head:

```
# Pseudocode — adapt to your logger/print statement of choice
function riskyStep(value):
    log("ENTER riskyStep", value=value, caller=currentStackTrace())
    result = doWork(value)
    log("EXIT riskyStep", result=result)
    return result
```

Practical notes:
- Log *before* the operation that might fail, not just in the catch block — by the time you're in a catch block you've often lost the input that caused it.
- In test suites specifically, use whatever output channel isn't swallowed by the test runner (stderr and `console.error`-equivalents are usually safe bets; buffered stdout loggers sometimes aren't shown on failure).
- Capture a full stack, not just a message — `new Error().stack`, a language's traceback/backtrace facility, or an explicit caller parameter threaded through, depending on what's idiomatic in the stack you're in.
- Once you have output, grep it for the specific value or request ID you're chasing rather than reading the whole log linearly.

## Finding which caller/test/request triggers it

If you know *something* produces the bad state but not which one, bisection is faster than manual review — see `scripts/bisect-culprit.sh` for a general "run this check across a list of candidates" helper, and `scripts/collect-evidence.sh` for a quick way to gather the recent-history context that often narrows the candidate list before you even start bisecting.

## The shape of it

```
symptom → immediate cause → "what called this with that value?"
        → trace one level up → "is this where it was created?"
              → no: keep tracing backward
              → yes: fix here, then add a boundary check so it can't happen again
```

Never stop at the first place that looks fixable if it isn't actually where the bad value was born — a fix placed midway through the chain just relocates the bug to whichever caller you didn't check.
