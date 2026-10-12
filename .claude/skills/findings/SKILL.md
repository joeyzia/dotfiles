---
name: findings
description: "Summarize the current conversation's investigation into a 1-pager and write it to the Obsidian vault. Use when wrapping up research, benchmarks, debugging sessions, or architectural explorations."
---

# Write Findings to Obsidian

You are tasked with summarizing the current conversation's investigation into a structured 1-pager document and saving it to the user's Obsidian vault.

## Obsidian Vault

Set these once for your machine (edit this block):

- **Path**: `~/notes/obsidian-vault` <!-- your vault -->
- **Content root**: `Work/` <!-- folder inside the vault for this job -->
- **Subfolders**: `Investigations/`, `Domain/`, `Personal/`
- **Template**: `Templates/1-Pager.md` (optional)

## Process

1. **Review the conversation** to identify:
   - What was investigated (the question, hypothesis, or problem)
   - What methodology was used (benchmarks, code analysis, log searches, etc.)
   - What data was collected (metrics, timings, sizes, counts)
   - What conclusions were drawn
   - What recommendations came out of it
   - Any related Jira tickets

2. **Pick the right subfolder**:
   - `Investigations/` — debugging sessions, performance benchmarks, root cause analysis
   - `Domain/` — findings specific to the product domain you work on
   - If unclear, default to `Investigations/`

3. **Generate the 1-pager** using this template structure:

```markdown
|                  |                     |
| ---------------- | ------------------- |
| **Published**    | {YYYY-MM-DD}        |
| **Authors**      | {from git config}   |
| **Jira Tickets** | {if any, link them} |
| **Status**       | Draft               |

## What

{1-2 paragraphs: what was investigated and the outcome. Focus on the conclusion, not the process.}

## Why

{Why this investigation matters. Business context, operational risk, or architectural decision it informs.}

{## Additional sections as needed — use headers that fit the content:}
{- "## Current State" for describing what exists today}
{- "## Benchmark Results" for performance data (use tables)}
{- "## Findings" for numbered takeaways}
{- "## Recommendation" for actionable next steps (use a table if context-dependent)}

## Other Considerations

{Security, compliance, developer experience, migration risk, etc.}

## Additional Reading

{Links to RFCs, blog posts, Confluence pages, benchmark code locations, etc.}
```

4. **File naming**: `{Title} - {YYYY-MM-DD}.md`
   - Example: `UUID V7 Insert Performance - 2026-05-13.md`

5. **Present the draft to the user** before writing:
   - Show the target path
   - Show a summary of what will be included
   - Ask: "I'll write this to `{path}`. Look good?"

6. **Write the file** upon confirmation.

## Guidelines

- **Be concise.** This is a 1-pager, not a report. Aim for something someone can read in 3-5 minutes.
- **Lead with findings, not process.** The reader wants to know what you learned, not the blow-by-blow of how you got there.
- **Use tables for data.** Benchmark results, comparison matrices, and recommendations with context all work well as tables.
- **Include raw data location.** If benchmarks were run, link to where the code/data lives so it's reproducible.
- **No emojis** unless the user asks for them.
- **Get the author name** from `git config user.name` if not obvious from conversation context.
