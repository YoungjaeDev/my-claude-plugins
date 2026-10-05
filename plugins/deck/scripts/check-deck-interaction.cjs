#!/usr/bin/env node
"use strict";

let chromium;
try {
  ({ chromium } = require("playwright"));
} catch (_error) {
  // Resolved from the plugin root's node_modules (installed from package-lock.json), else NODE_PATH.
  console.error(JSON.stringify({ status: "failed", errorType: "MissingPlaywright", message: "playwright not found. Run `npm ci` in the deck plugin root, or set NODE_PATH to a node_modules that has playwright." }));
  process.exit(1);
}
const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const path = require("path");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
};

// Chrome comes from --chrome, then $CHROME, then the platform's standard install path.
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
  for (const required of ["input", "output-dir", "expected-slides"]) {
    if (!values[required]) throw new Error(`Missing --${required}`);
  }
  const expectedSlides = Number(values["expected-slides"]);
  if (!Number.isInteger(expectedSlides) || expectedSlides < 1) throw new Error("--expected-slides must be a positive integer");
  return {
    input: path.resolve(values.input),
    outputDir: path.resolve(values["output-dir"]),
    expectedSlides,
    chrome: path.resolve(values.chrome || defaultChrome()),
  };
}

function sha256(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function inside(root, file) {
  const relative = path.relative(root, file);
  return relative !== "" && relative !== ".." && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative);
}

function serve(root) {
  const canonicalRoot = fs.realpathSync(root);
  return new Promise(resolve => {
    const server = http.createServer((request, response) => {
      try {
        const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
        if (pathname === "/favicon.ico") {
          response.writeHead(204);
          response.end();
          return;
        }
        const requested = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
        const candidate = path.resolve(canonicalRoot, requested);
        if (!inside(canonicalRoot, candidate) || !fs.existsSync(candidate) || !fs.statSync(candidate).isFile()) {
          response.writeHead(404);
          response.end("not found");
          return;
        }
        const file = fs.realpathSync(candidate);
        if (!inside(canonicalRoot, file)) {
          response.writeHead(404);
          response.end("not found");
          return;
        }
        response.writeHead(200, { "Content-Type": MIME[path.extname(file).toLowerCase()] || "application/octet-stream" });
        fs.createReadStream(file).pipe(response);
      } catch (_error) {
        response.writeHead(400);
        response.end("bad request");
      }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function closeEnough(actual, expected, tolerance = 1) {
  return Math.abs(actual - expected) <= tolerance;
}

async function preparePage(context, url, requestProblems) {
  await context.addInitScript(() => localStorage.clear());
  await context.route("**/*", async route => {
    const target = new URL(route.request().url());
    if (target.protocol === "data:" || ["127.0.0.1", "localhost"].includes(target.hostname)) await route.continue();
    else {
      requestProblems.push(`external-request:${target.protocol}//${target.hostname}${target.pathname}`);
      await route.abort();
    }
  });
  const page = await context.newPage();
  page.on("pageerror", error => requestProblems.push(`pageerror:${error.name}:${error.message.slice(0, 160)}`));
  page.on("response", response => {
    if (response.status() >= 400) requestProblems.push(`http:${response.status()}:${new URL(response.url()).pathname}`);
  });
  page.on("requestfailed", request => {
    const target = new URL(request.url());
    if (["127.0.0.1", "localhost"].includes(target.hostname)) requestProblems.push(`local-request-failed:${target.pathname}`);
  });
  await page.goto(url, { waitUntil: "load" });
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all([...document.images].map(image => image.decode()));
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });
  return page;
}

async function state(page) {
  return page.evaluate(() => {
    const slides = [...document.querySelectorAll(".slide")];
    const active = slides.map((slide, index) => slide.classList.contains("active") ? index : -1).filter(index => index >= 0);
    const visible = slides.map((slide, index) => slide.classList.contains("visible") ? index : -1).filter(index => index >= 0);
    const ariaVisible = slides.map((slide, index) => slide.getAttribute("aria-hidden") === "false" ? index : -1).filter(index => index >= 0);
    return { slideCount: slides.length, currentSlide: window.presentation?.currentSlide ?? null, active, visible, ariaVisible, hash: location.hash };
  });
}

function checkState(observation, expectedIndex, label, failures) {
  const expectedHash = `#slide-${expectedIndex + 1}`;
  const okay = observation.currentSlide === expectedIndex &&
    observation.active.length === 1 && observation.active[0] === expectedIndex &&
    observation.visible.length === 1 && observation.visible[0] === expectedIndex &&
    observation.ariaVisible.length === 1 && observation.ariaVisible[0] === expectedIndex &&
    observation.hash === expectedHash;
  if (!okay) failures.push({ check: label, expectedIndex, expectedHash, observed: observation });
  return okay;
}

async function motionState(page, waitForEnd) {
  // 첫 data-motion 장표로 가서 GSAP 타임라인 진행도를 읽는다. 없으면 skipped로 남긴다.
  const index = await page.evaluate(() => [...document.querySelectorAll(".slide")].findIndex(slide => slide.dataset.motion));
  const reduced = await page.evaluate(() => matchMedia("(prefers-reduced-motion: reduce)").matches);
  if (index < 0) return { reduced, skipped: "no data-motion slide" };
  await page.evaluate(value => window.presentation.showSlide(value), index);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const progressOnEntry = await page.evaluate(() => window.presentation.motionProgress());
  let reachedEnd = null;
  if (waitForEnd) {
    reachedEnd = await page.waitForFunction(() => window.presentation.motionProgress() === 1, null, { timeout: 15000 }).then(() => true, () => false);
  }
  return { reduced, index, progressOnEntry, reachedEnd };
}

async function scaleState(page) {
  return page.evaluate(() => {
    const stage = document.querySelector(".deck-stage");
    const box = stage.getBoundingClientRect();
    return {
      viewport: [innerWidth, innerHeight],
      datasetScale: Number(document.documentElement.dataset.stageScale),
      box: { left: box.left, top: box.top, width: box.width, height: box.height },
    };
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.input) || !fs.statSync(args.input).isFile() || path.extname(args.input).toLowerCase() !== ".html") throw new Error("--input must be an existing HTML file");
  if (!fs.existsSync(args.chrome)) throw new Error(`Chrome not found: ${args.chrome}`);
  if (fs.existsSync(args.outputDir)) throw new Error(`Output directory already exists: ${args.outputDir}`);
  fs.mkdirSync(args.outputDir, { recursive: true });

  const failures = [];
  const requestProblems = [];
  const observations = { keyboard: [], hash: [], history: [], inputFocus: [], resize: [], motion: {}, resources: null };
  const server = await serve(path.dirname(args.input));
  const baseUrl = `http://127.0.0.1:${server.address().port}/${encodeURIComponent(path.basename(args.input))}`;
  let browser = null;
  let browserVersion = null;
  try {
    browser = await chromium.launch({ headless: true, executablePath: args.chrome });
    browserVersion = browser.version();

    const normalContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, reducedMotion: "no-preference" });
    const page = await preparePage(normalContext, baseUrl, requestProblems);
    let observed = await state(page);
    if (observed.slideCount !== args.expectedSlides) failures.push({ check: "slide-count", expected: args.expectedSlides, observed: observed.slideCount });
    checkState(observed, 0, "initial-no-hash", failures);
    observations.resources = await page.evaluate(() => ({
      documentFontsStatus: document.fonts.status,
      fontFaces: [...document.fonts].map(face => ({ family: face.family, weight: face.weight, status: face.status })),
      resources: performance.getEntriesByType("resource").map(entry => entry.name),
      images: [...document.images].map(image => ({ src: image.currentSrc || image.src, decoded: image.complete && image.naturalWidth > 0 })),
    }));
    if (observations.resources.documentFontsStatus !== "loaded" || observations.resources.fontFaces.some(face => face.status !== "loaded")) {
      failures.push({ check: "local-font-load", observed: observations.resources });
    }
    if (observations.resources.images.some(image => !image.decoded)) failures.push({ check: "local-image-decode", observed: observations.resources.images });
    for (const resource of observations.resources.resources) {
      const target = new URL(resource);
      if (!["127.0.0.1", "localhost"].includes(target.hostname)) failures.push({ check: "non-local-resource", resource });
    }

    let expectedIndex = 0;
    const lastIndex = args.expectedSlides - 1;
    const keySequence = ["Home", "ArrowRight", "PageDown", "Space", "End", "ArrowLeft", "PageUp", "Home", "PageUp", "End", "PageDown"];
    for (const key of keySequence) {
      if (key === "Home") expectedIndex = 0;
      else if (key === "End") expectedIndex = lastIndex;
      else if (["ArrowRight", "PageDown", "Space"].includes(key)) expectedIndex = Math.min(lastIndex, expectedIndex + 1);
      else expectedIndex = Math.max(0, expectedIndex - 1);
      await page.keyboard.press(key);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
      observed = await state(page);
      observations.keyboard.push({ key, expectedIndex, observed });
      checkState(observed, expectedIndex, `key:${key}`, failures);
    }

    await page.keyboard.press("Home");
    await page.waitForTimeout(20);
    await page.evaluate(() => {
      window.__interactionHashEvents = 0;
      window.addEventListener("hashchange", () => { window.__interactionHashEvents += 1; });
    });
    const runtimeValidIndex = Math.min(3, lastIndex);
    const runtimeValidHash = `#slide-${runtimeValidIndex + 1}`;
    await page.evaluate(hash => { location.hash = hash; }, runtimeValidHash);
    await page.waitForTimeout(50);
    observed = await state(page);
    observations.hash.push({ case: "runtime-valid", requested: runtimeValidHash, observed });
    checkState(observed, runtimeValidIndex, "hash-runtime-valid", failures);
    const runtimeInvalidHashes = ["#slide-not-a-number", "#slide-0", "#slide--1", `#slide-${args.expectedSlides + 1}`];
    for (const invalidHash of runtimeInvalidHashes) {
      await page.evaluate(hash => { location.hash = hash; }, invalidHash);
      await page.waitForTimeout(50);
      observed = await state(page);
      observations.hash.push({ case: "runtime-invalid", requested: invalidHash, observed });
      checkState(observed, 0, `hash-runtime-invalid:${invalidHash}`, failures);
    }
    const hashEventCount = await page.evaluate(() => window.__interactionHashEvents);
    observations.hashEventCount = { triggeredChanges: 1 + runtimeInvalidHashes.length, observed: hashEventCount };
    if (hashEventCount > 1 + runtimeInvalidHashes.length) failures.push({ check: "hash-recursion", observed: hashEventCount, maximum: 1 + runtimeInvalidHashes.length });

    await page.evaluate(() => {
      const host = document.createElement("div");
      host.id = "interaction-input-probes";
      host.innerHTML = [
        '<button id="probe-button">button</button>',
        '<input id="probe-input">',
        '<textarea id="probe-textarea"></textarea>',
        '<select id="probe-select"><option>one</option><option>two</option></select>',
        '<div contenteditable="true"><span id="probe-editable-child" tabindex="0">editable child</span></div>',
      ].join("");
      document.body.appendChild(host);
    });
    for (const selector of ["#probe-button", "#probe-input", "#probe-textarea", "#probe-select", "#probe-editable-child"]) {
      await page.evaluate(() => window.presentation.showSlide(0));
      await page.locator(selector).focus();
      await page.keyboard.press("ArrowRight");
      await page.waitForTimeout(20);
      observed = await state(page);
      observations.inputFocus.push({ selector, key: "ArrowRight", observed });
      checkState(observed, 0, `input-focus:${selector}`, failures);
    }
    await page.evaluate(() => document.getElementById("interaction-input-probes")?.remove());

    // 첫 패널 장표에서 연다 → 복사 버튼 확인 → 열린 동안 방향키 차단 → Esc로 닫고 포커스 복귀 → 방향키 이동 재개.
    const panelIndex = await page.evaluate(() => [...document.querySelectorAll(".slide")].findIndex(slide => slide.querySelector("button.reveal-btn[data-panel]")));
    if (panelIndex < 0) observations.panel = { skipped: "no reveal-btn slide" };
    else {
      await page.evaluate(value => window.presentation.showSlide(value), panelIndex);
      const trigger = page.locator(".slide.active button.reveal-btn[data-panel]").first();
      await trigger.click();
      const opened = await page.evaluate(() => ({
        open: !!document.querySelector("deck-panel [role=dialog]"),
        copyButtons: document.querySelectorAll("deck-panel .deck-copy").length,
        expectCopy: (tpl => tpl?.dataset.kind === "prompt" || !!tpl?.content.querySelector("pre"))(document.getElementById(document.querySelector(".slide.active button.reveal-btn[data-panel]").dataset.panel)),
        focusInside: !!document.activeElement?.closest("deck-panel"),
      }));
      await page.keyboard.press("ArrowRight");
      await page.waitForTimeout(20);
      const whileOpen = await state(page);
      await page.keyboard.press("Escape");
      await page.waitForTimeout(20);
      const closed = await page.evaluate(() => ({
        open: !!document.querySelector("deck-panel"),
        focusOnTrigger: !!document.activeElement?.matches("button.reveal-btn[data-panel]"),
      }));
      const arrow = panelIndex < lastIndex ? "ArrowRight" : "ArrowLeft";
      await page.keyboard.press(arrow);
      await page.waitForTimeout(20);
      const afterClose = await state(page);
      observations.panel = { panelIndex, opened, whileOpen, closed, arrow, afterClose };
      if (!opened.open || (opened.expectCopy && opened.copyButtons < 1) || !opened.focusInside) failures.push({ check: "panel-open", observed: opened });
      checkState(whileOpen, panelIndex, "panel-blocks-arrow", failures);
      if (closed.open || !closed.focusOnTrigger) failures.push({ check: "panel-escape", observed: closed });
      checkState(afterClose, arrow === "ArrowRight" ? panelIndex + 1 : panelIndex - 1, "panel-arrow-after-close", failures);
    }

    for (const viewport of [{ width: 1920, height: 1080 }, { width: 1280, height: 720 }, { width: 390, height: 844 }]) {
      await page.setViewportSize(viewport);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const scale = await scaleState(page);
      const factor = Math.min(viewport.width / 1920, viewport.height / 1080);
      const expected = { width: 1920 * factor, height: 1080 * factor, left: (viewport.width - 1920 * factor) / 2, top: (viewport.height - 1080 * factor) / 2 };
      observations.resize.push({ ...scale, expected });
      if (!closeEnough(scale.datasetScale, factor, 0.00001) || !closeEnough(scale.box.width, expected.width) || !closeEnough(scale.box.height, expected.height) || !closeEnough(scale.box.left, expected.left) || !closeEnough(scale.box.top, expected.top)) {
        failures.push({ check: `resize:${viewport.width}x${viewport.height}`, expected, observed: scale });
      }
    }
    observations.motion.normal = await motionState(page, true);
    if (observations.motion.normal.reduced || (!observations.motion.normal.skipped && !(observations.motion.normal.progressOnEntry < 1 && observations.motion.normal.reachedEnd))) {
      failures.push({ check: "motion-normal", observed: observations.motion.normal });
    }
    await normalContext.close();

    const validInitialIndex = Math.min(2, args.expectedSlides - 1);
    const validInitialHash = `#slide-${validInitialIndex + 1}`;
    const validHashContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, reducedMotion: "no-preference" });
    const validHashPage = await preparePage(validHashContext, `${baseUrl}${validInitialHash}`, requestProblems);
    observed = await state(validHashPage);
    observations.hash.push({ case: "initial-valid", requested: validInitialHash, observed });
    checkState(observed, validInitialIndex, "hash-initial-valid", failures);
    await validHashContext.close();

    for (const invalidHash of ["#slide-not-a-number", "#slide-0", "#slide--1", `#slide-${args.expectedSlides + 1}`]) {
      const invalidHashContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, reducedMotion: "no-preference" });
      const invalidHashPage = await preparePage(invalidHashContext, `${baseUrl}${invalidHash}`, requestProblems);
      observed = await state(invalidHashPage);
      observations.hash.push({ case: "initial-invalid", requested: invalidHash, observed });
      checkState(observed, 0, `hash-initial-invalid:${invalidHash}`, failures);
      await invalidHashContext.close();
    }

    if (args.expectedSlides > 1) {
      const historyContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, reducedMotion: "no-preference" });
      const historyPage = await preparePage(historyContext, baseUrl, requestProblems);
      await historyPage.keyboard.press("ArrowRight");
      let historyIndex = 1;
      if (args.expectedSlides > 2) {
        await historyPage.keyboard.press("PageDown");
        historyIndex = 2;
      }
      await historyPage.goBack();
      await historyPage.waitForTimeout(50);
      observed = await state(historyPage);
      observations.history.push({ action: "back", observed });
      checkState(observed, historyIndex - 1, "history-back", failures);
      await historyPage.goForward();
      await historyPage.waitForTimeout(50);
      observed = await state(historyPage);
      observations.history.push({ action: "forward", observed });
      checkState(observed, historyIndex, "history-forward", failures);
      await historyContext.close();
    } else {
      observations.history.push({ action: "skipped", reason: "single-slide deck has no adjacent history state" });
    }

    const reducedContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, reducedMotion: "reduce" });
    const reducedPage = await preparePage(reducedContext, baseUrl, requestProblems);
    observations.motion.reduced = await motionState(reducedPage, false);
    if (!observations.motion.reduced.reduced || (!observations.motion.reduced.skipped && observations.motion.reduced.progressOnEntry !== 1)) {
      failures.push({ check: "motion-reduced", observed: observations.motion.reduced });
    }
    await reducedContext.close();
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }

  for (const problem of requestProblems) failures.push({ check: problem });
  const report = {
    status: failures.length ? "failed" : "verified",
    input: args.input,
    inputSha256: sha256(args.input),
    expectedSlides: args.expectedSlides,
    browserVersion,
    supportedKeysTested: ["ArrowRight", "ArrowLeft", "Home", "End", "PageUp", "PageDown", "Space"],
    observations,
    requestProblems,
    failures,
    minimalFixSuggestion: failures.some(item => item.check.startsWith("hash-") || item.check.startsWith("history-") || item.check.startsWith("input-focus:"))
      ? "첫 showSlide 전에 유효한 #slide-N을 읽고 hashchange를 재귀 없이 처리한다. 잘못됐거나 범위를 벗어난 hash는 1장으로 정규화하고, 내비게이션 키는 contenteditable 조상과 input·textarea·select·button에서 무시한다."
      : null,
  };
  const reportPath = path.join(args.outputDir, "interaction-report.json");
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");
  console.log(JSON.stringify({ status: report.status, failures: failures.length, keyboardChecks: observations.keyboard.length, hashChecks: observations.hash.length, resizeChecks: observations.resize.length }));
  return failures.length ? 1 : 0;
}

main().then(code => { process.exitCode = code; }).catch(error => {
  console.error(JSON.stringify({ status: "failed", errorType: error.name, message: error.message }));
  process.exitCode = 1;
});
