---
name: purge-git-history
description: "Use when sensitive data or proprietary content must be removed from Git history, hosted branches, pull requests, caches, forks, or clones. Use before rewriting or deleting a repository; not for routine file deletion."
---

# Purge sensitive Git history

Use this procedure only for an authorized request to remove data from Git history or hosted copies. Deleting a file does not remove its older commits, pull-request refs, caches, forks, or clones.

## Confirm scope and authority

1. Confirm the repository, the data to remove, affected branches and hosts, and the requested level of removal. Removing data from one branch differs from removing every hosted copy.
2. Confirm that the requester owns the repository or can approve a history rewrite. Do not rewrite remote history, close pull requests, delete a repository, or request elevated credentials without explicit authorization for that action.
3. If the data is an active secret, revoke or rotate it first. That may remove the risk without a history rewrite.
4. Keep secret values out of prompts, shell arguments, logs, comments, and skill output. Store replacement files outside the repository and protect them as secrets.
5. Stop pushes and coordinate open pull requests before rewriting. Close affected pull requests. Never merge a branch that contains the data. Ask collaborators to re-clone or clean their old branches; a later push can restore the removed data.

## Rewrite a fresh clone

Read GitHub's [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) before choosing commands. It documents history-rewrite effects, `git-filter-repo` options, and GitHub's support process.

1. Clone the repository into a new, private working directory. Confirm that `origin` points to the intended repository. Do not use a clone with unknown refs or uncommitted changes.
2. Use the current `git-filter-repo` release and its documented sensitive-data-removal mode. For a file, include its full repository-relative path and every former path. For text, keep replacements in a protected file outside the repository. Never put secret values on the command line.

   For a file:

   ```sh
   git-filter-repo --sensitive-data-removal --invert-paths --path path/to/file
   ```

   For text replacements:

   ```sh
   git-filter-repo --sensitive-data-removal --replace-text /secure/path/replacements.txt
   ```

3. Review the filter report before pushing. Check the first changed commits, changed refs, and affected pull-request count. Stop if any path, ref, or count is unexpected.
4. Verify every intended branch and tag without printing the removed value. Check other remotes and known forks separately. Rewriting `origin` does not rewrite those copies.
5. Ask the repository owner to confirm the affected refs. A mirror push overwrites remote refs and can discard newer work. Run it only after explicit approval.

```sh
git push --force --mirror origin
```

GitHub marks `refs/pull/*` as read-only, so a mirror push can fail on those refs. Do not retry a direct deletion of a hidden pull-request ref. A successful branch push does not prove that hosted copies are clean.

## Handle hosted pull requests and copies

For sensitive data, contact GitHub Support after cleaning writable refs. Provide the repository, affected pull-request count, first changed commits, and any orphaned LFS data reported by `git-filter-repo`. Support may dereference or delete pull requests, clear cached views, and purge server storage when its policy applies. Support does not remove non-sensitive data and may decline if credential rotation is enough.

Coordinate cleanup with fork and clone owners. You cannot remove another person's clone, and a fork can keep the old commits available. Give collaborators safe re-clone or rebase instructions. Never merge a branch based on the old history into the cleaned repository.

If the request covers a name or other non-sensitive content, GitHub Support may not remove cached pull-request references. Do not claim that a repository rewrite removed every copy. Report which refs you checked, which hosted copies remain, and what Support or fork owners must remove.

## Treat repository deletion as a separate action

Repository deletion is not the default purge method. It does not remove forks or local clones, and it does not prove that cached views were purged. If the owner separately requests deletion, confirm the repository and irreversible consequences. Check `gh auth status`; `gh auth refresh -h github.com -s delete_repo` may be required. Do not request that scope for a history rewrite.

## Verify and report

1. Confirm that each intended writable branch and tag points to the rewritten history. Record the refs checked without printing sensitive values.
2. Record affected pull requests, the GitHub Support outcome, known forks, collaborator cleanup, and remaining local copies.
3. Say "complete" only for the scope you verified. Report unchecked hidden refs, caches, forks, or clones as remaining limits.
4. Record the repository, refs, first changed commit, verification method, remaining copies, and next step in the issue or incident record. Never include the removed value.
