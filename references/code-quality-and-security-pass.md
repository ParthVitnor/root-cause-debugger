# Code Quality and Security Pass

## When to run this

At the end of stage 5 of the main workflow, on the code you just touched and its immediate neighborhood — and any time you're asked directly to review a codebase for bugs, quality, or vulnerabilities, independent of a specific bug report. This isn't a full audit checklist to run line-by-line over an entire repository; it's a lens to apply while you already have context loaded on a piece of code, plus a starting point if a full review is what was actually requested.

This is intentionally language-agnostic. The categories below apply regardless of stack; the per-language section at the end maps them to concrete tools.

## Quality checklist

Look for, in roughly descending order of how often they cause real bugs later:

- **Swallowed errors** — an empty catch block, a broad `except: pass`, a promise rejection with no handler, a return code that's checked and ignored. These turn real failures into silent ones that surface somewhere else, much later, disconnected from the actual cause.
- **Resource leaks** — file handles, network connections, database sessions, locks that are acquired but not reliably released on every exit path (including exceptions/errors, not just the happy path).
- **Unclear failure modes** — a function that returns `None`/`null`/a sentinel value on failure instead of raising, with callers that don't check for it (this is exactly the shape of the bug in `backward-tracing.md`'s example).
- **Duplicated logic** — the same rule or calculation implemented more than once. When it's next changed, updating only one copy creates a new bug that looks exactly like the class of bug you were just fixing.
- **Functions doing too much** — if you can't summarize what a function does in one sentence without "and", it's a candidate for splitting; harder-to-reason-about code is harder to debug the next time something in it breaks.
- **Magic values** — unexplained numbers or strings load-bearing enough that a wrong copy-paste of the value would silently break behavior.
- **Dead code** — code that's unreachable or that nothing calls anymore. Harmless until someone "fixes" it, assuming it's live, and ships a change with zero effect while believing the bug is resolved.

## Security checklist

Common categories, independent of language:

- **Injection** — untrusted input concatenated directly into a SQL query, shell command, file path, or template, instead of using parameterized queries, an escaping/quoting API, or an allowlist.
- **Hardcoded secrets** — API keys, passwords, tokens, or credentials committed directly in source rather than pulled from environment variables or a secrets manager.
- **Insecure deserialization** — deserializing untrusted data with a mechanism that can execute arbitrary code as a side effect (e.g., unrestricted object deserialization, unsafe YAML/pickle-style loaders) instead of a safe/restricted mode.
- **Missing authorization checks** — an endpoint or function that checks *who* the caller is (authentication) but not whether they're allowed to act on the specific resource requested (authorization) — a very common source of one-user-can-read-another-user's-data bugs.
- **Unsafe dynamic execution** — building and running code, shell commands, or queries from strings assembled at runtime (`eval`, `exec`, shelling out with unsanitized arguments) where a fixed, non-dynamic approach would do.
- **Weak or homemade cryptography** — a hand-rolled hashing/encryption scheme, a fixed or predictable IV/salt, or a deprecated algorithm, instead of a vetted standard library implementation.
- **Outdated dependencies with known vulnerabilities** — checked with the per-language tools below, not just by eyeballing version numbers.
- **Verbose error output leaking internals** — stack traces, internal paths, or query text returned directly in a user-facing error response.
- **Unrestricted file upload / path traversal** — accepting a filename or path from user input and using it to read or write on disk without validating it stays within an expected directory.
- **Server-side request forgery (SSRF)** — making an outbound HTTP request to a URL supplied by user input without restricting which hosts/schemes are reachable.

## Quick grep-able signals

Not proof of a problem on their own, but worth a closer look wherever they appear in changed or reviewed code:

| Signal | Roughly maps to |
|---|---|
| `eval(`, `exec(`, `new Function(` | Unsafe dynamic execution |
| `os.system(`, `subprocess` with `shell=True`, backtick/`` `cmd` `` shell-out | Command injection risk |
| String formatting/concatenation feeding directly into a query string | SQL/NoSQL injection risk |
| `pickle.loads(`, `yaml.load(` without a safe loader, `unserialize(` | Insecure deserialization |
| Variable names like `password =`, `api_key =`, `secret =` assigned a literal string | Hardcoded secret |
| `md5(`, `sha1(` used for password hashing specifically | Weak hashing for credentials (fine for non-security checksums) |
| `Math.random()` / non-cryptographic RNG used for tokens, session IDs, or secrets | Predictable secret generation |

`scripts/scan-signals.sh` runs the six patterns above (everything except the SQL/NoSQL row — string-concatenation into a query doesn't grep precisely enough to be worth automating; read how each query is built instead) across your changed files by default, or an explicit path. It's a faster first pass, not a replacement for reading the code — a hit is a signal, not a verdict, and a clean run doesn't mean the category is clean, just that grep didn't find anything.

## Per-language dependency/vulnerability tooling

Run the relevant one when a full review (not just a spot-check) is in scope, or when a suspicious dependency surfaced during the investigation:

| Ecosystem | Tool |
|---|---|
| Node / npm | `npm audit`, `yarn audit`, `pnpm audit` |
| Python | `pip-audit`, `safety check` |
| Ruby | `bundler-audit` |
| Go | `govulncheck` |
| Rust | `cargo audit` |
| Java / Maven / Gradle | OWASP Dependency-Check, `mvn org.owasp:dependency-check-maven:check` |
| PHP / Composer | `composer audit` |
| .NET | `dotnet list package --vulnerable` |

## Reporting what you find

Fold findings into the harden-and-sweep step rather than a separate disconnected list: note what you found, why it matters, and whether you fixed it now or it needs a separate follow-up (some findings — like a broad architectural authz gap — are correctly out of scope for a bug-fix change and should be flagged rather than expanded into a much larger unrequested change).
