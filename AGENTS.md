# Working rules

## Voice

- Terse. Say the thing, stop. No preamble, no recap of what you just did, no
  "great question", no restating the task back.
- No filler adjectives (robust, seamless, powerful, comprehensive, production-grade).
  State briefly what the code does, not how good it is.
  Don't paraphrase what the next lines of code do. Instead
  explain WHY and HOW if that really helps understanding.
- Docs and READMEs: what it is, how to use it, what it exposes. Nothing else.
- Commit messages: conventional-commit, imperative, one line where possible.
  Get the scope right — release tooling may route on it. Breaking changes get
  `!` (`feat(api)!: …`) or a `BREAKING CHANGE:` footer. Subject line ≤ 72 chars,
  imperative mood ("add", "fix", not "added", "fixes"). Body wraps at 72.
- Prefer small, focused commits. Release tooling often derives version bumps and
  the changelog from commit subjects.
- No ticket numbers in code, commits, or docs.
- Comments explain *why*, not *what*. Code comments state intent or a constraint
  the code cannot show. Delete comments that restate the code.
- Always consider comments and docs as a whole. Never just append. Revalidate them
  in their context and update to factual state. Research in the codebase if in
  doubt. Remove stale and out-of-context references, former observations,
  depictions of situations that led to a previous change, machine names or
  addresses, and any guesses about downstream usage of this repo and its artifacts
  apart from valid and up-to-date examples.
- Reference another repository or project only when its state is the direct reason
  for the change (a dependency bump, a vendored fix, an API contract pinned to a
  published version). Context for reviewers, gratitude, or cross-linking belongs in
  the PR thread or an issue, not the commit.
- Write declarative facts. No personal pronouns ("I", "we", "you"). Don't address a
  reader: no "note that…", "as you can see…", "we decided to…", "this should help…".
- Don't narrate. No history of what was tried first, what failed, or what
  alternatives were considered.
- No filler verbs without specifics. "Clean up", "improve", "refactor" alone tell
  nothing; either name the actual change or drop the line.
- No checklists, "Summary" / "Test plan" sections, marketing phrasing, or emojis.

## Before you finish

- Run the project's lint, tests, and build for everything touched.
- Don't claim done without running the check. Evidence before assertions.
- Drop any TODO marker you added during your session and re-iterate, or let the
  user know to create a follow-up. Remove all markers and references to your own
  tasklist or historical workitem/workphase (P2, P3a, Item 1, Task A, etc.) along
  with their narrative. If something is truly left open, tell the user outside of
  the code, docs, markdown, comments, PR descriptions, commit messages, or anything
  else inside this repo and its connected pipeline.
