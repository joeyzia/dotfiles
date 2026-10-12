---
name: git-commit
description: Create git commits with user approval and no Claude attribution
---

# Commit Changes

You are tasked with creating git commits for the changes made during this session.

## Process:

1. **Analyze the changes:**
   - Run `git status` and `git diff` to understand all modifications
   - Review the conversation history to understand what was accomplished and why
   - **Actively decide** whether changes should be one commit or multiple — don't default to one

2. **Decide on commit granularity:**
   Split into multiple commits when changes span distinct concerns. Ask yourself:
   - Are there dependency/module changes that should land separately? (go.mod, package.json, etc.)
   - Are there infrastructure/config changes separate from code logic? (Helm values, CI, Terraform)
   - Are there changes to shared packages vs service-specific wiring?
   - Could any subset of these changes be reverted independently?

   Keep as one commit when:
   - All changes serve a single, atomic purpose that doesn't make sense split up
   - Splitting would leave intermediate commits in a broken build state

3. **Plan your commit(s):**
   - Group files by logical concern, not by directory
   - Draft clear commit messages — imperative mood, focused on *why*
   - For multi-commit plans: ensure each commit builds and makes sense on its own
   - Follow the repo's commit conventions (check CLAUDE.md or recent `git log`)

4. **Present your plan to the user:**
   - List the files for each commit
   - Show the commit message(s)
   - If you chose to keep it as one commit, briefly explain why splitting wasn't warranted
   - Ask: "I plan to create [N] commit(s) with these changes. Shall I proceed?"

5. **Execute upon confirmation:**
   - Use `git add` with specific files (never use `-A` or `.`)
   - Create commits in order with your planned messages
   - Show the result with `git log --oneline -n [number]`

## Important:

- **NEVER add co-author information or Claude attribution**
- Commits should be authored solely by the user
- Do not include any "Generated with Claude" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them

## Remember:

- You have the full context of what was done in this session
- Group related changes together
- Keep commits focused and atomic when possible
- The user trusts your judgment - they asked you to commit
