---
id: issue-close-sources
aliases: [closing-keyword-non-default-base, closingIssuesReferences, post-merge-issue-close]
last_verified: 2026-09-21
status: active
volatility: stable
sources: 4
---

# "Closes #N" is one claim with four sources and two ways to be ignored

A merged pull request whose body says `Closes #10` normally closes issue 10. When it does not, nothing says so: the body still reads `Closes #10`, the PR page shows no warning, and a cleanup step that trusts the body reports success over an issue that is still open.

Two conditions turn the keyword off, and both are ordinary:

- **The base is not the default branch.** "If the pull request targets any other branch, then these keywords are ignored, no links are created, and merging the PR has no effect on the issues." Not merely unhonoured — *unlinked*, so the link-based surfaces stay empty too.
- **The repository disabled auto-close.** Settings → General → Issues → "Auto-close issues with merged linked pull requests". Here the link exists and the merge simply does not act on it.

## Do not read the link set as a closure set

`closingIssuesReferences` is documented as the issues that *may* be closed by the pull request, and it includes issues linked by hand. Subtracting it from the issues the body names therefore hides the exact case worth finding: an issue that is linked and still open. The issue's own `state` is the direct signal and costs one call.

That demotes the field from evidence to **a source of candidates, which it still is** — an issue linked through the PR sidebar appears in no body and in no commit message, so a text scan alone never reaches it.

## Four sources, none of which subsumes the others

| Source | Holds what the others do not |
|---|---|
| PR body | the ordinary case |
| Commit messages on the PR | GitHub honours a closing keyword in a commit message; it need never appear in the body |
| The merge commit's own message | composed in GitHub's merge dialog at merge time, so it exists in no PR commit |
| `closingIssuesReferences` | issues linked by hand, which no text carries |

Two ceilings sit on the commit source: `gh pr view --json commits` returns 100, and the REST endpoint it wraps returns 250 even with `--paginate`. A count that comes back at exactly the ceiling is a truncated scan, not a clean one.

And nine keywords, not three: `close`/`closes`/`closed`, `fix`/`fixes`/`fixed`, `resolve`/`resolves`/`resolved`. Matching only the `-s` forms misses `Fixed #123`, which GitHub honours and which, on a non-default base, leaves nothing behind to find it by.

## Host is a field, not a default

Once cross-repository refs are in scope, every `gh` call needs the host stated. `gh api` defaults to `github.com` whatever the local remote is, and `--repo owner/repo` does the same. On a GitHub Enterprise repository an unqualified call reads — and closes — the same-numbered issue on the wrong server, silently.

The failure that survives one round of fixing is the asymmetric one: pinning the host on the read path and leaving the write path unqualified means the state came from one server and the close goes to another. Pin both, or pass the URL, which carries its host and needs no assembly. The same applies to the close comment: its body is rendered in the *issue's* repository, so a bare `#<PR>` there resolves to that repository's own number. Use the pull request's URL.

## Sources

- GitHub docs — Linking a pull request to an issue (the non-default-base note, the nine keywords, the cross-repository syntax)
- GitHub docs — Managing the automatic closing of issues in your repository
- GitHub GraphQL reference — `closingIssuesReferences` ("issues that may be closed")
- GitHub PR #262 (`dev` 3.6.3; 11 review rounds, 17 findings applied)

> Evidence: https://github.com/YoungjaeDev/my-claude-plugins/pull/262
> See-also: [[review-loop-churn]]
