### Opening a PR

Invoked at the end of every other playbook.

**Worktree.** Work from a git worktree off main. Bind or isolate delegated sessions through the active adapter. Concurrent writers each get a distinct branch and worktree. Work on one branch is serialized; refresh a clean worktree from the exact remote branch only between sequential sessions. Dirty branch with unrelated work: patch out, fresh worktree, apply. Snarled worktree: reset from main, redo minimally.

**Commits.** Commit liberally; rebase into small, ordered commits before opening PRs. Each commit is a future PR: landable, ordered to tell the story. Amend when the fix belongs in a just-made commit; new commit when separable.

**PRs.** Run **unslop** over the diff before commit. Run **no-comments** before review. Write every PR title, PR description, and commit body with **technical-writing**, then apply **unslop**. Apply every technical-writing layer except Diataxis. Use one word for each action, keep articles, and avoid `-ing` when a plain verb works.

**Titles.** Use Conventional Commits in the form `type(scope): subject`. Use `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, or `perf` as the type. Use the changed area, such as `poteto-mode` or the repo name, as the scope. Keep the subject short and imperative. Apply the same **technical-writing** and **unslop** pass as the body. Name a real symbol when one carries the change. For example, `fix(poteto-mode): port the 0.14.5 multi-phase plan`. Do not add a trailing period.

**Descriptions.** Use these sections in order. Drop a section when it is empty.

- `## Why`. State the intent and why this approach fits.
- `## Scope`. State facts from the diff. Name real symbols and paths. Name both sides of a rename or retarget. State what is in and out when the boundary matters.
- `## Tradeoffs`. State real choices only. Skip this section when there are none.
- `## Blast Radius`. State who and what the change touches. Explain why the change is safe or risky. If main is red without the fix, name the continuing cost.
- `## Verification`. State how you ran each check and its rigor. Name the real path, such as the installed control capability or the targeted tests. State the outcome of each check, not only the command name.

After these sections, attach videos or screenshots when they prove a claim. Do not use `## Summary` or `## Test plan` boilerplate. A commit body does not restate its subject.

**Size and stacks.** Prefer five narrow PRs to one large PR. Stack follow-ups with the team's stacking tool, and keep the ordered stack visible to reviewers. Branch from main only for independent work. Rebase on `main` before substantial stack work. `gh pr view <number>` before you refer to PR status.

**Readiness.** Open every PR ready, never as a draft. Delegated PR tools default to draft, so set `draft: false` on every PR creation call. If a PR still opens as a draft, run the host's ready command, such as `gh pr ready <number>`.

**Babysit.** Opening a PR does not start a babysit. Post the URL and keep building. Finish the phase or stack first. Run a separate babysit pass only when the user asks for one after the whole stack exists. A babysit for each new PR stalls the build and spends checks on commits that later waves restart. Route to **Babysit** when the user asks for PR-status work such as "get it green", "check the PR", or "merge-ready". Push back when feedback drifts from intent.

Before authorizing delegated PR opening, the root runs **interrogate**, **unslop**, and **no-comments** and supplies the accepted frozen diff. The root starts one canonical `mechanical` participant through the active adapter's **Bounded session** protocol. The opener performs only the authorized commit, push, and PR creation, returns the URL, and does not babysit.
