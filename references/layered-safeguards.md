# Layered Safeguards

## The idea

Fixing a bug at the exact spot it was found feels complete, but a single checkpoint is fragile: a different code path, a new caller, a mock in a test, or a future refactor can all route around it without anyone noticing. A check that lives in only one place is a check that can be silently bypassed.

**Core move:** once you've found and fixed the root cause, add validation at every layer the bad data passes through on its way to causing damage — not just the one layer where you happened to catch it this time. The goal isn't "we patched the bug," it's "this class of bug can't happen here anymore."

## Why more than one layer

Each layer catches something the others miss:
- The entry point catches most malformed input before it goes anywhere
- Core logic catches values that were valid on entry but became invalid given other state (a discount that's fine alone but not combined with a coupon, say)
- Context-specific guards catch things that are only dangerous in a particular environment (a destructive operation that's fine in production but must never run in a test sandbox, or vice versa)
- Observability doesn't prevent anything, but it means the *next* failure like this one is fast to diagnose instead of starting from zero again

## Worked example

**Bug:** a scheduling system accepted a negative `duration_minutes` for a booking, which produced a booking that ends before it starts and corrupted downstream availability calculations.

**Layer 1 — boundary validation, where the request enters:**
```
function createBooking(input):
    if input.duration_minutes is None or input.duration_minutes <= 0:
        reject("duration_minutes must be a positive number")
    # ...continue
```

**Layer 2 — invariant check in core logic, where the object is actually constructed** (catches cases that skip the API boundary — internal callers, batch jobs, migrations):
```
function Booking.__init__(self, start, duration_minutes):
    assert duration_minutes > 0, "Booking duration must be positive"
    self.end = start + duration_minutes
```

**Layer 3 — context guard, for operations that are only safe in specific environments:**
```
function runMigrationScript():
    if environment != "staging" and not explicitly_confirmed:
        abort("Refusing to run destructive migration outside staging without confirmation")
```
(Not every bug needs this layer — it applies when the danger is context-dependent, like a bulk-delete script or a signing step that must never touch production credentials by accident.)

**Layer 4 — observability, so the next occurrence is fast to find:**
```
function createBooking(input):
    log.debug("booking request received", duration=input.duration_minutes, source=caller_id())
    ...
```

## Applying this after your own fix

1. Identify every place the value or state you just fixed actually flows through — not just the crash site.
2. Add a check at the boundary (layer 1) if one isn't already there.
3. Add an invariant check at the point of construction/use (layer 2) so internal callers that skip the boundary are still caught.
4. Only add a context guard (layer 3) if the danger is genuinely context-specific — don't add one reflexively.
5. Add or confirm logging (layer 4) at the point where things could go wrong, so a recurrence is diagnosable in minutes instead of hours.
6. Try to break each layer on purpose — feed it the bad value through a different path (an internal call, a mock, a batch job) and confirm the *next* layer still catches it.

## Signal you're missing a layer

If a bug you already "fixed" comes back through a different caller, a mocked test, or a code path you didn't think to check — that's not a new bug, it's the same bug with one fewer safeguard than it needed. Add the missing layer rather than patching that specific new caller.

## Don't overdo it

Four layers is illustrative, not a quota. A purely internal helper function with one caller and no security implications might reasonably need just a boundary check and an invariant. Match the number of layers to how many independent ways the bad state could actually reach this code, not to a fixed checklist.
