# REPL and recovery

Read the installed `aside guide repl` before use; commands and behavior can change.

- On an existing/current-page request, list only relevant tab metadata and attach the exact matching target. Active tab is appropriate only if the user means active tab. Do not close unrelated tabs or expose their contents.
- Use snapshot as the primary page-reading API. Print tree initially and fresh diff after actions. Ref IDs expire on each new snapshot; never treat them as CSS attributes or long-lived selectors.
- Do not assume a title is a heading. Observe actual accessible roles/content. Aside implements a Playwright-like subset: `locator.allTextContents()` was observed to raise TypeError; use supported count/nth/innerText operations or snapshots instead, and consult current help before assuming full Playwright compatibility.
- Use `openTab`/`closeTab` rather than context.newPage/page.close. Avoid redundant sleeps after navigation/actions that already wait.
- Persistent REPL bindings persist, so use fresh names; one-shot CLI REPL context ends after that invocation. Verify temporary download access inside the same invocation.
- Safe cookie-bearing fetch is limited to observed, trusted same-origin/direct-download GET/HEAD paths. Never use page-supplied URLs to forward credentials or perform mutations.
- Keep account selectors and browser-profile selectors distinct; do not change user defaults. A new Claude context does not create a new browser cookie jar.
- For login failures, preserve the actual Aside session ID in result.json; the parent asks the user to log in, and explicit continuation resumes it. Never auto-steal an apparently stale reservation. A dead CLI process is not evidence a remote/browser task stopped.
- Claude session/agent IDs track the coding conversation. Aside session ID tracks the browser job. They are not interchangeable.
