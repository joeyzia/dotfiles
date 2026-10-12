---
name: journal-preflight
description: "Pre-flight check for journal update MCP connections. Sends a macOS notification if any need re-authentication."
user_invocable: true
---

# Journal Preflight

Check that all MCP connections needed by `/journal-update` are authenticated. If any fail, send a macOS notification so you can re-auth before the journal run.

## Instructions

1. Test each MCP source with a minimal call:
   - **Google Calendar**: `list_events` with a 1-hour window today, pageSize 1
   - **Zoom**: `search_meetings` for today, page_size 1
   - **Slack**: `slack_search_public_and_private` with a trivial query
   - **Lucid**: `search` with a simple query
   - **Jira**: `searchJiraIssuesUsingJql` with maxResults 1

2. Collect results into a pass/fail list.

3. If ALL pass, send a success notification:
   ```bash
   osascript -e 'display notification "All 5 MCP connections healthy. Journal update ready." with title "Journal Preflight ✓"'
   ```

4. If ANY fail, send a warning notification listing which ones:
   ```bash
   osascript -e 'display notification "Slack, Zoom need re-auth. Run /mcp in Claude Code." with title "Journal Preflight ✗"'
   ```

5. Print the checklist to stdout regardless:
   ```
   Journal Preflight Check:
   [x] Google Calendar
   [x] Zoom
   [ ] Slack — needs re-authentication
   [x] Lucid
   [x] Jira
   ```

6. **If ANY source failed**, append the explicit reconnect instructions to stdout — the actionable next steps, not just the failure list:
   ```
   ⚠️  Journal-update is BLOCKED until reconnection.

   To reconnect:
     1. Run `/mcp` in Claude Code
     2. For each failed server above, select it and follow the auth flow
     3. Re-run `/journal-preflight` to verify
     4. Then run `/journal-update`

   Note: /mcp must be invoked by the user — Claude cannot run it programmatically.
   ```

## Rules
- This is READ-ONLY. Do not create or modify any files.
- Do not write to any external service.
- Keep it fast — minimal calls only.
