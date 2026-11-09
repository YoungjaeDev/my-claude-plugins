# e2e-setup scaffolds

The three file bodies `e2e-setup` writes into a user's project when the file does not exist yet: the Path B/C environment seed (Step 2), a new `playwright.config.ts` (Step 3) and the auth setup test (Step 4). Write each one as shown and adjust only what the project dictates (base URL, login labels, `testDir`).

## Environment seed (Step 2, Path B/C)

Path A gets the seed and `specs/` from `init-agents`; Path B/C create them here because the planner runs `seed.spec.ts` first and `e2e-author` requires it. Skip either file if it exists. Write `seed.spec.ts` under the project's `testDir`, or under `e2e/` (the `testDir` of the Step 3 config) when there is no config yet:

```ts
// Default environment seed the planner runs first (Path B/C stand-in for the
// init-agents output). Establishes baseline app state; expand per your app.
import { test, expect } from "@playwright/test";

test("seed: app reachable", async ({ page }) => {
  await page.goto(process.env.E2E_BASE_URL ?? "http://localhost:3000");
  await expect(page).toHaveTitle(/.*/);
});
```

and `specs/README.md` (the test-plan directory):

```md
# specs/ — test plans

Human-readable planner output, one Markdown file per critical user flow.
The generator turns an approved `specs/<flow>.md` into `e2e/<flow>.spec.ts`.
```

## New playwright.config.ts (Step 3)

Only when no `playwright.config.*` exists. It carries the setup-project pattern from Step 4 plus reporter and trace defaults:

```ts
import { defineConfig, devices } from "@playwright/test";
export default defineConfig({
  testDir: "./e2e",
  retries: process.env.CI ? 2 : 0,
  reporter: [["html"], ["list"]],
  use: { baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3000", trace: "on-first-retry" },
  projects: [
    { name: "setup", testMatch: /.*\.setup\.ts/ },
    { name: "chromium", use: { ...devices["Desktop Chrome"], storageState: "playwright/.auth/user.json" }, dependencies: ["setup"] },
  ],
  // webServer: { command: "npm run dev", url: "http://localhost:3000", reuseExistingServer: !process.env.CI },
});
```

## Auth setup test (Step 4)

`e2e/auth.setup.ts` is a `setup` project test that logs in once and saves the state for every other project:

```ts
import { test as setup, expect } from "@playwright/test";
import path from "path";
const authFile = path.join(__dirname, "../playwright/.auth/user.json");
setup("authenticate", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill(process.env.E2E_USER!);
  await page.getByLabel("Password").fill(process.env.E2E_PASS!);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("button", { name: /account|profile/i })).toBeVisible();
  await page.context().storageState({ path: authFile });
});
```
