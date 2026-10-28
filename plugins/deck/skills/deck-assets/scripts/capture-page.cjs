#!/usr/bin/env node
"use strict";
// Screenshot running pages (a result app, a docs page) at a fixed viewport for a deck.
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch (_error) {
  console.error("playwright not found. Run `npm ci` in the deck plugin root, or set NODE_PATH to a node_modules that has playwright.");
  process.exit(1);
}
const fs = require("fs");
const path = require("path");

const USAGE = `usage: capture-page.cjs --out DIR [--base URL] [--viewport 390x844] [--scale 2]
         [--storage key=value]... [--blur CSS_SELECTOR]... [--suffix NAME] [--wait MS] [--full] TARGET...
TARGET is a full URL, or a path such as /users/me when --base is given.
Writes DIR/<slug>[-<suffix>].png per target. --storage presets localStorage before the page loads
(for a theme: --storage theme=dark --suffix dark). --blur injects filter:blur on matching elements.
Browser: bundled Chromium, else system Chrome (channel 'chrome').`;

function parse(argv) {
  const a = { storage: [], blur: [], targets: [], viewport: "390x844", scale: 2, wait: 600 };
  const need = (i) => {
    if (i + 1 >= argv.length) throw new Error(`${argv[i]} needs a value`);
    return argv[i + 1];
  };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === "--out") a.out = need(i++);
    else if (k === "--base") a.base = need(i++);
    else if (k === "--viewport") a.viewport = need(i++);
    else if (k === "--scale") a.scale = Number(need(i++));
    else if (k === "--storage") a.storage.push(need(i++));
    else if (k === "--blur") a.blur.push(need(i++));
    else if (k === "--suffix") a.suffix = need(i++);
    else if (k === "--wait") a.wait = Number(need(i++));
    else if (k === "--full") a.full = true;
    else if (k === "-h" || k === "--help") { console.log(USAGE); process.exit(0); }
    else if (k.startsWith("--")) throw new Error(`unknown option ${k}`);
    else a.targets.push(k);
  }
  const m = /^(\d+)x(\d+)$/.exec(a.viewport);
  if (!a.out || !a.targets.length || !m || !(a.scale > 0)) throw new Error("need --out, at least one target, --viewport WxH, --scale N");
  a.vp = { width: Number(m[1]), height: Number(m[2]) };
  a.kv = a.storage.map((s) => {
    const j = s.indexOf("=");
    if (j < 1) throw new Error(`--storage wants key=value, got ${s}`);
    return [s.slice(0, j), s.slice(j + 1)];
  });
  return a;
}

function toUrl(t, base) {
  if (/^https?:\/\//.test(t)) return t;
  if (!base) throw new Error(`${t} is not a URL and --base is not set`);
  return base.replace(/\/$/, "") + (t.startsWith("/") ? t : "/" + t);
}

function slug(url) {
  const u = new URL(url);
  const s = (u.pathname + u.search).replace(/[^A-Za-z0-9]+/g, "-").replace(/^-|-$/g, "");
  return s || "index";
}

async function launch() {
  try {
    return await chromium.launch();
  } catch (error) {
    console.error(`bundled Chromium unavailable (${String(error.message).split("\n")[0]}); falling back to system Chrome`);
    try {
      return await chromium.launch({ channel: "chrome" });
    } catch (error2) {
      throw new Error(`system Chrome failed too: ${String(error2.message).split("\n")[0]}. Install Chrome or run \`npx playwright install chromium\`.`);
    }
  }
}

(async () => {
  let a;
  try {
    a = parse(process.argv.slice(2));
  } catch (error) {
    console.error(error.message + "\n" + USAGE);
    process.exit(2);
  }
  fs.mkdirSync(a.out, { recursive: true });
  const browser = await launch();
  try {
    const ctx = await browser.newContext({ viewport: a.vp, deviceScaleFactor: a.scale });
    if (a.kv.length) await ctx.addInitScript((kv) => kv.forEach(([k, v]) => localStorage.setItem(k, v)), a.kv);
    const page = await ctx.newPage();
    for (const t of a.targets) {
      const url = toUrl(t, a.base);
      await page.goto(url, { waitUntil: "networkidle" });
      if (a.blur.length) await page.addStyleTag({ content: `${a.blur.join(",")}{filter:blur(6px)!important}` });
      await page.waitForTimeout(a.wait);
      const file = path.join(a.out, `${slug(url)}${a.suffix ? "-" + a.suffix : ""}.png`);
      await page.screenshot({ path: file, fullPage: !!a.full });
      console.log(file);
    }
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
