#!/usr/bin/env node
"use strict";
// Screenshot one slide's motion at chosen times, to look at mid-states the end-state render never shows.
//   motion-frames.cjs --input deck/index.html --output-dir DIR --slide 12|S3-04 --at 0,500,1500,end
// The timeline is paused and seeked, so a late time costs no waiting. 0 is the state right after the motion is
// built (where a fromTo's immediateRender shows up), end is the authored end state. PNGs: slide-<NN>-<ID>-<ms>.png.
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch (_error) {
  console.error(JSON.stringify({ status: "failed", errorType: "MissingPlaywright", message: "playwright not found. Run `npm ci` in the deck plugin root, or set NODE_PATH to a node_modules that has playwright." }));
  process.exit(1);
}
const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

function defaultChrome() {
  if (process.env.CHROME) return process.env.CHROME;
  if (process.platform === "darwin") return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  if (process.platform === "win32") return "C:/Program Files/Google/Chrome/Application/chrome.exe";
  return "/usr/bin/google-chrome";
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = argv[index];
    const value = argv[index + 1];
    if (!key?.startsWith("--") || !value || value.startsWith("--")) throw new Error(`Invalid argument near ${key || "<end>"}`);
    values[key.slice(2)] = value;
  }
  for (const required of ["input", "output-dir", "slide", "at"]) if (!values[required]) throw new Error(`Missing --${required}`);
  const at = values.at.split(",").map(token => token.trim());
  if (!at.every(token => /^(\d+|end)$/.test(token))) throw new Error("--at takes milliseconds and/or end, comma-separated");
  return { input: path.resolve(values.input), outputDir: path.resolve(values["output-dir"]), slide: values.slide, at, chrome: values.chrome || defaultChrome() };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.input)) throw new Error(`Input not found: ${args.input}`);
  fs.mkdirSync(args.outputDir, { recursive: true });
  const browser = await chromium.launch({ headless: true, executablePath: args.chrome });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, reducedMotion: "no-preference" });
    await page.goto(pathToFileURL(args.input).href, { waitUntil: "load" });
    await page.addStyleTag({ content: ".edit-hotzone, .edit-toggle, .deck-controls { display: none !important; }" });
    await page.evaluate(() => document.fonts.ready);
    const ids = await page.evaluate(() => [...document.querySelectorAll(".slide")].map(slide => (slide.getAttribute("aria-label") || "").split(" ")[0]));
    const index = /^\d+$/.test(args.slide) ? Number(args.slide) - 1 : ids.indexOf(args.slide);
    if (index < 0 || index >= ids.length) throw new Error(`--slide: no slide ${args.slide} (deck has ${ids.length})`);
    // Build the motion and pause it before its first tick; the same hash first so show() does not rebuild it.
    const found = await page.evaluate(slideIndex => {
      history.replaceState(null, "", `#slide-${slideIndex + 1}`);
      window.presentation.showSlide(slideIndex);
      const slide = document.querySelectorAll(".slide")[slideIndex];
      if (!window.gsap) return false;
      const timeline = gsap.globalTimeline.getChildren(false, false, true)
        .filter(child => child.getChildren(true, true, false).some(tween => tween.targets().some(target => target instanceof Element && slide.contains(target)))).pop();
      if (!timeline) return false;
      timeline.pause();
      window.__motionFrames = timeline;
      return true;
    }, index);
    if (!found) throw new Error(`slide ${index + 1} ${ids[index]} has no running motion`);
    const ms = args.at.filter(token => token !== "end").map(Number).sort((a, b) => a - b);
    const number = String(index + 1).padStart(String(ids.length).length, "0");
    const id = ids[index].replace(/[^A-Za-z0-9_-]/g, "_");
    for (const token of [...ms, ...(args.at.includes("end") ? ["end"] : [])]) {
      await page.evaluate(value => {
        if (value === "end") window.__motionFrames.progress(1, true);
        else if (value > 0) window.__motionFrames.seek(value / 1000, true);
      }, token);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const file = path.join(args.outputDir, `slide-${number}${id ? `-${id}` : ""}-${token === "end" ? "end" : `${String(token).padStart(5, "0")}ms`}.png`);
      await page.screenshot({ path: file });
      console.log(file);
    }
    return 0;
  } finally {
    await browser.close();
  }
}

main().then(code => { process.exitCode = code; }).catch(error => {
  console.error(JSON.stringify({ status: "failed", errorType: error.name, message: error.message }));
  process.exitCode = 1;
});
