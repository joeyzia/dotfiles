# Global Instructions

## Response Contract

How to shape every reply. Derived from 3 months of evidence (session logs,
Slack, Zoom): comprehension fails on response *shape*, not user ability.

### The shape

1. **Verdict first.** Answer in sentence one, ≤15 words. Detail after — or not at all.
2. **~120-word budget** for explanations. Headers/bold/bullets do not rescue a
   long reply — cut narration and meta-talk instead. Never cut by assuming
   unstated context (no allusive shorthand, no unexplained notation — unpack
   `key:{a}-{b}` style templates immediately).
3. **One thread per reply.** Answer the question asked; hold everything else.
   Side-findings get one line at the end, expandable on request.
4. **Conclusion, not investigation.** Never narrate tracing/searching. Report
   what was found and what it means.
5. **Never relitigate.** A decided thing gets restated in 1 line, not defended
   in an essay. "Kept because X." Done.

### How to explain

6. **Concrete instance immediately.** Real event names, field names, IDs,
   numbers ("account 123 arrives, then 124, then 123 again — overwrites").
   Abstract definitions don't land; toy examples do.
7. **Temporal sequence for mechanisms.** A fires → B hasn't committed → C
   drops it. This is the native format.
8. **Scenario table for branching logic** — then point at the one row that
   differs. Offer a mermaid diagram when a change needs mental gymnastics.
9. **Analogy bridge when introducing something new**: map to HTTP, Temporal,
   Kafka — systems already owned.

### The dialogue loop

10. **Engage the hypothesis.** Questions arrive hypothesis-first ("sanity
    check — X right?"). Confirm/correct THAT model in one line; never restart
    from zero. A wrong premise gets challenged with a mechanism ("that can't
    3x because...").
11. **A "right?" paraphrase is the comprehension protocol.** Confirm or deny
    it in one line. A confirmed paraphrase ends the thread.
12. **Decisions: max 2 options, labeled, one-line recommendation up front.**
    Never end with an open menu ("what do you want to do?"). If questions
    were numbered ("one:... two:..."), mirror the numbering.

### Escape hatch

"go deep" / "full detail" in a message lifts the budget for that reply only.

### Auto-clarity exception

Drop brevity for: security warnings, irreversible-action confirmations,
multi-step sequences where compression risks misread.

## Scope Discipline

- Implement the smallest change that satisfies the request. Do not add metrics
  counters, new error contracts, refactors, or ripple changes to callers unless
  explicitly asked.
- Before writing code, state the proposed diff scope in 2-3 bullets and wait for
  confirmation if it touches more than 2 files.
- A hardening or bugfix request is not an invitation to redesign. If the fix
  needs an error-contract change, propose it — don't implement it.

## Verification

- Never assert PR/merge/deploy state from memory. Run
  `gh pr view <n> --json state,mergedAt,mergeCommit` before claiming a PR is
  merged or unmerged.
- After any change to error-handling behavior, grep for unit tests asserting the
  old behavior before pushing (CI has broken this way).
- Read the config/code before answering "what value does X use" — don't answer
  generically and make the user supply the ID.

## Git Workflow

- Work in a separate git worktree for any change that will become a PR:
  `git worktree add ../<repo>-<ticket> -b <branch>`. Verify `pwd` before the
  first edit.
- Branch off the repo's actual default branch
  (`gh repo view --json defaultBranchRef`), not an assumed `main`.

## Commit Attribution

- **NEVER add Co-Authored-By lines or Claude attribution to commits**
- Do not include "Generated with Claude" or similar messages in commit bodies
- Write commit messages as if the user wrote them — the user is accountable for all code changes

## Go Skill Trial (started 2026-09-04)

`/go-spf13` invokes spf13's idiomatic Go skill on demand. It never fires on its own —
day-to-day Go work runs on the rules below and the repo's `.claude/rules/`.

When it is invoked, it does not know the current repo's conventions. Where it argues
against them — package layout, where shared structs live, interface placement — this
file and the repo's own rules win.

It says nothing about comment style or vertical whitespace, so the rules below stand.

To end the trial: `rm -rf ~/.claude/skills/go-spf13` and delete this section.

## Coding Rules

<!-- INCUBATING (added 2026-07-29) — trial rule. Delete this block if it doesn't earn its place. -->

### No positional collection access at call sites

Don't reach into a collection by a literal index (`items[0]`, `resp.Txns[0]`) at a call
site, and don't pair it with a `len(x) == 0` guard-then-index dance. It's the same smell as
an index-based `for i := range xs { xs[i] }` loop — reaching into a collection by position.

When an API returns a batch/slice shape but the call is single-item, collapse it to one value
(or an error) at the **client/boundary layer that owns the 1:1 contract** — validate the count
is exactly what's expected (`!= 1`, not just `== 0`), return the single element there once, and
document why it's 1:1. Callers get one value and never see `resp.X[0]`.

```go
// smell — bounds dance + positional index at the call site
if len(resp.Txns) == 0 { return fmt.Errorf("...: empty txns") }
res := resp.Txns[0]

// prefer — client returns the one result; the sole [0] lives where 1:1 is owned
res, err := c.AddTierPoints(ctx, req)   // errors if len(resp.Txns) != 1
```
<!-- END INCUBATING -->

### Comment style

**Never add an explanatory comment to code.** No inline comment describing what a line does, no block comment summarizing a function. Comments that already existed in the file stay. This rule has needed repeating — treat it as a hard stop, not a preference.

Write one only when a reader who has the name, the signature and the surrounding code would still be wrong about something. Most code clears that bar without help. Doc comments describe the function or type as a whole — not each field.

- **Only exported items get a doc comment**, and it is **one line** (two max, if the second carries a fact the signature can't). Start with the item's name.
- **Unexported funcs, types and helpers get no doc comment.** Rename them instead — a well-named private helper needs no prose.
- **Never explain a decision in source.** If a comment argues why this approach, why not the alternative, what used to be true, or what breaks without it — cut it. That goes in the commit message or PR body, which is where someone asking "why" looks. This is the failure mode to watch for.
- **Struct fields stay bare** unless a field's meaning isn't self-evident from its name and type; then one short trailing fragment, never a multi-line block above the field. Go's exported-doc lint rule (`revive`'s `exported`) covers exported types/functions/methods/consts/vars, **not** struct fields — bare fields still pass.
- Inline comments are lowercase fragments, **one line**, only where the code alone misleads. Don't restate what the name says.
- **Tests get no doc comments** — on test funcs or helpers. The test name is the description.

### Vertical whitespace

Give function bodies breathing room — separate each logical step with a blank line. `gofmt` preserves blank lines but never adds them, so write them in from the start (no linter enforces this).

- Blank line before `if`/`for`/`switch`/`select`, unless the line directly above is an assignment the block consumes.
- Blank line after a block before the next unrelated statement — including a trailing `return` or a plain call.

```go
out := make([]string, 0, len(names))

for _, n := range names {
    if skip(n) {
        continue
    }
    out = append(out, n)
}

slices.Sort(out)

return out
```

