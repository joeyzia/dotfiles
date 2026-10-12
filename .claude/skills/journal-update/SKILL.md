---
name: journal-update
description: Update the work journal with recent activity from GitHub, Jira, Calendar, Zoom, Lucid, and Slack. Run daily or weekly to keep the journal current.
---

# Journal Update

Update an Obsidian work journal with recent activity, one entry per weekday, plus a running brag sheet and a yearly summary.

## Configuration — edit this block for your machine and job

| Key | Example | Meaning |
|---|---|---|
| `VAULT` | `~/notes/obsidian-vault` | Git repo holding the Obsidian vault |
| `ROOT` | `Work/Personal` | Folder inside the vault for journal + brag sheet |
| `GIT_ROOT` | `~/git` | Where work repos are cloned (`{GIT_ROOT}/{org}/{repo}`) |
| `GIT_AUTHOR_PATTERN` | `yourname\|yourhandle` | `git log --author` regex matching every identity you commit as |
| `GH_ACCOUNTS` | `work-handle:org-a,org-b` | One entry per GitHub account → the orgs it can see |
| `MERGE_REPOS` | `org-a/service-1 org-a/service-2` | Repos to scan for PRs you merged for others (Step C) |
| `JIRA_CLOUD_ID` | `xxxxxxxx-xxxx-…` | Atlassian cloud id |
| `JIRA_PROJECT` | `ABC` | Project key; ticket regex becomes `ABC-\d+` |
| `SLACK_USER` | `your.name` | Your Slack handle for `from:` searches |
| `SLACK_CHANNELS` | `#team-dev #team-alerts` | Channels to scan for your messages |
| `TZ` | `America/New_York` | Timezone for meeting windows |

Paths below use `{ROOT}` for `{VAULT}/{ROOT}`.

## Instructions

1. **Pre-flight: check MCP connections**. Before gathering any data, test each MCP source with a minimal call. ALL five sources (Google Calendar, Zoom, Slack, Lucid, Jira) are required.
   - **Google Calendar**: call `list_events` with a 1-hour window today, pageSize 1
   - **Zoom**: call `search_meetings` for today, page_size 1
   - **Slack**: call `slack_search_public_and_private` with a trivial query
   - **Lucid**: call `search` with a simple query
   - **Jira**: call `searchJiraIssuesUsingJql` with maxResults 1

   Print the results like:
   ```
   MCP Connection Check:
   [x] Google Calendar
   [x] Zoom
   [ ] Slack — needs re-authentication
   [x] Lucid
   [x] Jira
   ```

   **HALT POLICY**: If ANY connection fails, STOP. Do not proceed to step 2. Print:
   ```
   ⚠️  Journal-update halted — required MCP source(s) are disconnected.

   To proceed:
     1. Run `/mcp` in Claude Code
     2. Select each failed server above and complete the auth flow
     3. Re-run `/journal-update`

   Claude cannot invoke /mcp programmatically — this requires your action.
   ```
   Wait for the user to confirm reconnection before retrying. Do NOT partially proceed with the sources that ARE up — partial entries miss the tickets that anchor the day's context.

   **ONE EXCEPTION — past-only backfills may run without Jira.** Proceed instead of halting when *both* hold:
   1. **Jira is the only failed source.** The other four have no substitute — if Calendar, Zoom, Slack, or Lucid is down, halt regardless of range. Jira is carved out solely because it has a defined fallback (step 3).
   2. **The range ends strictly before today.** If `END_DATE >= today`, halt. A range covering today will be re-run anyway once the day closes; a range of finished days loses more by never being written.

   When the exception applies, use the step-3 ticket-key regex fallback over commit messages and PR titles, and write the Jira section as:
   ```
   ## Jira
   _Status unavailable — Jira MCP was disconnected during this run. Ticket keys below are from commits/PRs only; re-run to fill in summaries and statuses._
   - ABC-1234: (referenced in commits/PRs)
   ```
   Keep that italic marker line verbatim so a later run can find and replace the section. Say plainly in the step-8 report that the Jira section is degraded and which dates are affected.

2. **Determine date range**:
   - If the user specifies a range (e.g., "last week"), use that.
   - Otherwise find the most recent entry: `ls "{ROOT}/Journal/{YYYY}/" | sort | tail -1`. Start is the day AFTER it; end is today.
   - Always include today even if its entry exists — it may be incomplete. The append-only rule in step 5 prevents duplication.
   - This backfills automatically if the laptop was off for several days.
   - Skip weekends unless the user explicitly asks for them.

3. **Gather data from all sources in parallel**:

   **GitHub Commits** (local repos, every identity in `GIT_AUTHOR_PATTERN`):

   **Step A — Fetch all remotes first** (separate command, before logging). Commits on merged branches won't appear in `git log --all` unless refs are current:
   ```bash
   find {GIT_ROOT} -maxdepth 3 -name ".git" -type d 2>/dev/null | while read gitdir; do
     git -C "$(dirname "$gitdir")" fetch --quiet 2>/dev/null &
   done
   wait
   ```

   **Step B — Scan commits** using `git -C` (never `cd` inside a pipe — it silently breaks):
   ```bash
   find {GIT_ROOT} -maxdepth 3 -name ".git" -type d 2>/dev/null | while read gitdir; do
     repo=$(dirname "$gitdir")
     reponame=$(echo "$repo" | sed "s|{GIT_ROOT}/||")
     case "$reponame" in */obsidian-vault|*" copy"*) continue ;; esac
     git -C "$repo" log --all --author="{GIT_AUTHOR_PATTERN}" \
       --since="START_DATET00:00:00" --until="END_DATE_PLUS_1T00:00:00" \
       --format="%ad | %s" --date=short --no-merges 2>/dev/null \
       | while read line; do echo "$reponame: $line"; done
   done | sort -u
   ```

   **CRITICAL date format**: always use the `T00:00:00` suffix (`--since="2026-06-04T00:00:00"`). A bare date silently returns 0 results when it is today — git reads a bare today-date as "since right now" instead of "since midnight". This is the #1 cause of missing commits. Use `--all` for every branch, END_DATE_PLUS_1 as the exclusive upper bound, and `sort -u` to dedupe commits that sit on several branches.

   **GitHub PRs** (via `gh` — opened, merged, reviewed, merged-for-others).

   **Step A — run the three searches per account in `GH_ACCOUNTS`:**
   ```bash
   # PRs authored (created in range)
   gh search prs --author={handle} --created=START_DATE..END_DATE --limit=50 --json number,title,url,repository,state,createdAt
   # PRs merged in range (may have been created earlier — use --merged-at, NOT --merged, which is a boolean)
   gh search prs --author={handle} --merged-at=START_DATE..END_DATE_PLUS_1 --limit=50 --json number,title,url,repository,state,closedAt
   # PRs reviewed — MUST use --updated, NOT --created
   gh search prs --reviewed-by={handle} --updated=START_DATE..END_DATE_PLUS_1 --limit=50 --json number,title,url,repository,state,updatedAt,author
   ```

   **CRITICAL — review searches use `--updated`, never `--created`.** `--created` filters on when the PR was *opened*, so it drops every review given on a PR opened before the window — most of them. Verified in practice: `--created` returned 1 PR where `--updated` returned 3. Because `--updated` also matches PRs that merely changed, confirm a review was actually submitted before recording it:
   ```bash
   gh api repos/OWNER/REPO/pulls/N/reviews --jq '.[] | select(.user.login=="{handle}") | {state, submitted_at}'
   ```
   `state: PENDING` with `submitted_at: null` is an unsubmitted draft — record it as "review in progress", not as a review given.

   **Step B — accounts other than the active one need a switch.** `gh` can hold several accounts with only one active. Repos the active account can't see return 404, and `--author={other-handle}` searches return `[]` — the author flag does NOT switch identity. Switch, query, switch back:
   ```bash
   gh auth switch --user {other-handle}
   # ...the three Step A searches for that handle...
   gh auth switch --user {default-handle}   # ALWAYS switch back, even if the queries fail
   ```
   Cross-check against commit subjects: a local commit ending in `(#N)` is a squash-merged PR. If a `(#N)` appears in the commit scan but in none of the PR searches, the search missed it — record it from the commit.

   **Step C — PRs you merged for other people.** `gh search prs` has no `--merged-by` filter, and the pulls *list* endpoint returns `merged_by: null` — only the single-PR endpoint populates it. So it's two steps per repo in `MERGE_REPOS`, under the matching account:
   ```bash
   for R in {MERGE_REPOS}; do
     for N in $(gh api "repos/$R/pulls?state=closed&sort=updated&direction=desc&per_page=50" \
       --jq ".[] | select(.merged_at != null and (.merged_at | startswith(\"START_DATE\"))) | .number" 2>/dev/null); do
       gh api "repos/$R/pulls/$N" --jq "{repo:\"$R\", num:.number, author:.user.login, merged_by:.merged_by.login, title:.title}" 2>/dev/null
     done
   done
   ```
   Keep only rows where `merged_by` is one of your handles **and** `author` is someone else — record them as `(merged for <author>)` and count them in People & Coaching as an unblocking signal. Where you merged your own PR, Step A already covers it.

   **Cost**: this is the only expensive step. Keep `MERGE_REPOS` to repos you actually merge in, and skip org-wide config repos that merge dozens of PRs a day. If time-boxed, drop Step C and say so in the report rather than reporting zero.

   When correlating by date, use `closedAt` (equals merge time) for merged PRs. A PR created May 27 and merged Jun 1 belongs in the Jun 1 entry as "merged". Dedupe — a PR in both "created" and "merged-at" for the same range is listed once with both actions ("opened, merged").

   **Jira**: `project = {JIRA_PROJECT} AND assignee = currentUser() AND updated >= "START_DATE" ORDER BY updated DESC`, cloud id `{JIRA_CLOUD_ID}`.

   **Jira fallback** — reachable only via the step-1 past-only exception. Extract keys with `{JIRA_PROJECT}-\d+` from commits and PR titles, and write the section with the marker line from step 1.

   **Google Calendar**: `list_events` with startTime/endTime for the range. Large ranges overflow the tool output — extract with `jq` from the saved file.

   **Zoom**: `search_meetings` with from/to in UTC for the range (use `TZ`). Prefer Zoom's `history` records over calendar invites for who actually attended — an invite list is not attendance.

   **Lucid**: documents modified after START_DATE.

   **Slack**: `from:{SLACK_USER} after:START_DATE` in `SLACK_CHANNELS`. Captures top-level posts and thread replies.

   **Thread context for mentorship signal**: for substantive replies (>200 chars, in dev/eng channels — not alerts or bots), `slack_read_thread` the parent message. The parent's author is the person being helped. Skip short acks and bot/alert threads.

4. **Correlate by date**: group all sources by day.

5. **Create or update journal entries** at `{ROOT}/Journal/{YYYY}/YYYY-MM-DD.md`:
   - If it exists, **only append new data** — never delete, overwrite, or modify existing content.
   - Otherwise create it from this template:

   ```markdown
   ---
   date: YYYY-MM-DD
   ---

   # YYYY-MM-DD

   ## Summary
   1-2 sentence synthesis of the day's work based on all sections below.

   ## Commits
   - repo: commit message

   ## Pull Requests
   - repo#N: title (opened/merged/reviewed)

   ## Jira
   - TICKET-KEY: summary (status)

   ## Meetings
   - Meeting Name (N attendees — Name1, Name2 if ≤6 attendees)

   ## People & Coaching
   - 1:1 / small meeting partners: Name — topic if known
   - PR reviews given to: Name (repo#N — brief context)
   - PRs merged for: Name (repo#N — brief context)
   - Slack thread coaching: Name (#channel — topic from parent message)
   - Walkthroughs / KTs given to: Name1, Name2 — topic
   ```

   **People & Coaching** — stay factual. Names come from meeting attendees (≤6-attendee meetings only), PR review authors, PR authors you merged for (Step C), and parent authors of Slack threads you replied to substantively. Do NOT speculate about growth or impact — only the evidence trail. Omit empty categories. Anonymize interview candidates ("Senior SWE candidate").

6. **Update the brag sheet** at `{ROOT}/Brag Sheet/{YYYY}.md`.

   **6a. Append-only sections** — add anything promotion-worthy under the right existing heading: projects started or shipped, prod deploys, significant tickets completed, KTs/presentations hosted, interviews conducted, cross-team design work, shared-library contributions, infrastructure provisioned, incidents resolved. Never rewrite existing bullets. Update the "Last updated" line and the "By the Numbers" table.

   **6b. Regenerate `### Working Relationships`** under `## Mentorship & Collaboration`:
   1. Scan every journal entry for the current year.
   2. Extract people from ≤6-attendee meeting lines and `## People & Coaching`.
   3. Per person count: interactions, distinct dates, recurring 1:1s (2-attendee meetings), reviews given, PRs merged for them, Slack coaching threads.
   4. Include only people with **3+ interactions in the last 90 days**. Exclude >6-attendee meetings, interview candidates, one-off externals.
   5. One bullet each:
      ```
      - **Person Name** — N interactions across M dates since YYYY-MM-DD. Recurring 1:1s [cadence]. Joint work: [tickets, PRs, topics]. Walkthroughs / coaching: [reviews, KTs, thread topics where you were the SME].
      ```
   6. Sort by interaction count, descending.

   If you change how interactions are counted between runs, say so in the section's methodology note — otherwise a jump in counts reads as growth when it's a method change.

7. **Update the yearly summary** at `{ROOT}/Journal/{YYYY}/{YYYY} Summary.md`: add each day's `[[YYYY-MM-DD]]` to the right week table and that week's highlights; start a new week section when needed. Append only.

8. **Report** what was added (e.g. "Updated 3 entries: 05-13 (4 commits, 3 meetings), 05-14 (2 meetings). Added 1 brag-sheet item under Technical Impact."). Call out anything skipped or degraded.

9. **Commit and push** only the journal and brag-sheet files:
   ```bash
   cd {VAULT}
   git add "{ROOT}/Journal/" "{ROOT}/Brag Sheet/"
   git commit -m "journal: update YYYY-MM-DD"
   git push
   ```
   - Never `git add -A` or `git add .`. If the directory add would sweep in an untracked file you didn't create, stage explicit file paths instead.
   - For multiple days: `journal: update YYYY-MM-DD to YYYY-MM-DD`.
   - Nothing changed → skip the commit.

## Rules
- ONLY write inside `{ROOT}`.
- Do NOT post, comment, or write to any external service (Jira, Slack, GitHub, etc.).
- No PII in any entry: no customer names, account ids, emails, or interview candidate names.
- Correlate dates across all sources — each day's entry reflects ALL of them.
- Append-only, EXCEPT the brag sheet's `### Working Relationships`, which is regenerated each run.
- Teammates are not PII here — "1:1 with <teammate>" is the point. External names and candidates still get anonymized.
