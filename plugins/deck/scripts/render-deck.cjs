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
const { spawnSync } = require("child_process");

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
  ".ttf": "font/ttf",
  ".txt": "text/plain; charset=utf-8",
};

// Chrome comes from --chrome, then $CHROME, then the platform's standard install path.
function defaultChrome() {
  if (process.env.CHROME) return process.env.CHROME;
  if (process.platform === "darwin") return "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  if (process.platform === "win32") return "C:/Program Files/Google/Chrome/Application/chrome.exe";
  return "/usr/bin/google-chrome";
}

function usage() {
  return [
    "Usage: render-deck.cjs --input deck.html --output-dir DIR --expected-slides N [options]",
    "Options:",
    "  --chrome PATH    Chrome executable (default: $CHROME, else the platform's standard path)",
    "  --pdfinfo PATH   pdfinfo executable or command name (default: pdfinfo)",
    "  --pdf-name NAME  PDF filename (default: deck.pdf)",
  ].join("\n");
}

function parseArgs(argv) {
  const parsed = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) throw new Error(`Unexpected argument: ${key}`);
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for ${key}`);
    parsed[key.slice(2)] = value;
    index += 1;
  }
  for (const required of ["input", "output-dir", "expected-slides"]) {
    if (!parsed[required]) throw new Error(`Missing --${required}`);
  }
  const expectedSlides = Number(parsed["expected-slides"]);
  if (!Number.isInteger(expectedSlides) || expectedSlides < 1) throw new Error("--expected-slides must be a positive integer");
  const pdfName = parsed["pdf-name"] || "deck.pdf";
  if (path.basename(pdfName) !== pdfName || path.extname(pdfName).toLowerCase() !== ".pdf") {
    throw new Error("--pdf-name must be a basename ending in .pdf");
  }
  return {
    input: path.resolve(parsed.input),
    outputDir: path.resolve(parsed["output-dir"]),
    expectedSlides,
    chrome: path.resolve(parsed.chrome || defaultChrome()),
    pdfinfo: parsed.pdfinfo || "pdfinfo",
    pdfName,
  };
}

function sha256(file) {
  const digest = crypto.createHash("sha256");
  digest.update(fs.readFileSync(file));
  return digest.digest("hex");
}

function inside(root, file) {
  const relative = path.relative(root, file);
  return relative !== "" && !relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative);
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
        const file = path.resolve(canonicalRoot, requested);
        if (!inside(canonicalRoot, file) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
          response.writeHead(404);
          response.end("not found");
          return;
        }
        const canonicalFile = fs.realpathSync(file);
        if (!inside(canonicalRoot, canonicalFile)) {
          response.writeHead(404);
          response.end("not found");
          return;
        }
        response.writeHead(200, { "Content-Type": MIME[path.extname(canonicalFile).toLowerCase()] || "application/octet-stream" });
        fs.createReadStream(canonicalFile).pipe(response);
      } catch (_error) {
        response.writeHead(400);
        response.end("bad request");
      }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

const RENDER_CSS = `
  *, *::before, *::after { animation: none !important; transition: none !important; }
  .edit-hotzone, .edit-toggle, .deck-controls { display: none !important; }
  @media print { @page { size: 1920px 1080px; margin: 0; } }
`;

async function readyPage(browser, url, viewport, reducedMotion, problems) {
  const context = await browser.newContext({ viewport, reducedMotion });
  await context.addInitScript(() => localStorage.clear());
  await context.route("**/*", async route => {
    const target = new URL(route.request().url());
    if (target.protocol === "data:" || ["127.0.0.1", "localhost"].includes(target.hostname)) {
      await route.continue();
    } else {
      problems.push(`external-request:${target.protocol}//${target.hostname}${target.pathname}`);
      await route.abort();
    }
  });
  const page = await context.newPage();
  page.on("console", message => {
    if (message.type() === "error") problems.push(`console:${message.text().slice(0, 240)}`);
  });
  page.on("pageerror", error => problems.push(`pageerror:${error.name}`));
  page.on("requestfailed", request => {
    const target = new URL(request.url());
    if (["127.0.0.1", "localhost"].includes(target.hostname)) problems.push(`requestfailed:${target.pathname}`);
  });
  page.on("response", response => {
    if (response.status() >= 400) problems.push(`http:${response.status()}:${new URL(response.url()).pathname}`);
  });
  await page.goto(url, { waitUntil: "load" });
  await page.addStyleTag({ content: RENDER_CSS });
  const assets = await page.evaluate(async () => {
    await document.fonts.ready;
    const results = [];
    for (const image of [...document.images]) {
      try {
        await image.decode();
        results.push({ src: new URL(image.currentSrc || image.src).pathname, width: image.naturalWidth, height: image.naturalHeight, decoded: image.complete && image.naturalWidth > 0 });
      } catch (_error) {
        results.push({ src: new URL(image.currentSrc || image.src).pathname, width: image.naturalWidth, height: image.naturalHeight, decoded: false });
      }
    }
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return results;
  });
  for (const asset of assets) if (!asset.decoded) problems.push(`image-decode:${asset.src}`);
  return { context, page, assets };
}

async function auditKoreanFonts(page, index) {
  const markers = await page.evaluate(slideIndex => {
    const slide = document.querySelectorAll(".slide")[slideIndex];
    const marked = [];
    const seen = new Set();
    for (const element of slide.querySelectorAll("h1,h2,h3,p,li,pre,code,span,strong,td,th,figcaption,div")) {
      const directText = [...element.childNodes].filter(node => node.nodeType === Node.TEXT_NODE).map(node => node.nodeValue || "").join(" ");
      const style = getComputedStyle(element);
      for (const character of new Set([...directText].filter(value => /[가-힣]/.test(value)))) {
        const key = `${style.fontFamily}|${style.fontWeight}|${style.fontStyle}|${character}`;
        if (seen.has(key)) continue;
        seen.add(key);
        marked.push({ character, family: style.fontFamily, weight: style.fontWeight, fontStyle: style.fontStyle });
      }
    }
    return marked;
  }, index);
  if (!markers.length) return [];

  // Paint exactly one Hangul glyph at a time. Chromium can omit overlapping or
  // transparent audit nodes from its platform-font accounting, so a batch of
  // hidden samples produces false empty results.
  await page.evaluate(() => {
    const sample = document.createElement("span");
    sample.setAttribute("data-font-audit-sample", "true");
    sample.style.cssText = [
      "position:fixed", "left:16px", "top:16px", "z-index:2147483647",
      "display:inline-block", "font-size:40px", "line-height:1.2",
      "color:#000", "background:#fff", "opacity:1", "pointer-events:none",
    ].join(";");
    document.body.appendChild(sample);
  });
  const client = await page.context().newCDPSession(page);
  await client.send("DOM.enable");
  await client.send("CSS.enable");
  const documentNode = await client.send("DOM.getDocument", { depth: -1, pierce: true });
  const selected = await client.send("DOM.querySelector", { nodeId: documentNode.root.nodeId, selector: "[data-font-audit-sample]" });
  const reports = [];
  for (const marker of markers) {
    if (!selected.nodeId) {
      reports.push({ ...marker, fonts: [], fallback: true });
      continue;
    }
    await page.evaluate(async item => {
      const sample = document.querySelector("[data-font-audit-sample]");
      sample.textContent = item.character;
      sample.style.fontFamily = item.family;
      sample.style.fontWeight = item.weight;
      sample.style.fontStyle = item.fontStyle;
      await document.fonts.load(`${item.fontStyle} ${item.weight} 40px ${item.family}`, item.character);
      sample.getBoundingClientRect();
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    }, marker);
    const result = await client.send("CSS.getPlatformFontsForNode", { nodeId: selected.nodeId });
    const fonts = result.fonts.filter(font => font.glyphCount > 0).map(font => ({ familyName: font.familyName, postScriptName: font.postScriptName, glyphCount: font.glyphCount, isCustomFont: font.isCustomFont }));
    reports.push({ ...marker, fonts, fallback: fonts.length === 0 || fonts.some(font => !font.isCustomFont) });
  }
  await client.detach();
  await page.evaluate(() => document.querySelector("[data-font-audit-sample]")?.remove());
  return reports;
}

async function auditActualTextFonts(page, index) {
  const nodes = await page.evaluate(slideIndex => {
    const slide = document.querySelectorAll(".slide")[slideIndex];
    const result = [];
    let serial = 0;
    for (const element of slide.querySelectorAll("h1,h2,h3,p,li,pre,code,span,strong,td,th,figcaption")) {
      const text = [...element.childNodes]
        .filter(node => node.nodeType === Node.TEXT_NODE)
        .map(node => node.nodeValue || "")
        .join("");
      if (!text.trim()) continue;
      const id = `actual-font-${slideIndex}-${serial++}`;
      element.setAttribute("data-actual-font-id", id);
      result.push({
        id,
        textLength: [...text].length,
        hangulCount: [...text].filter(character => /[가-힣]/.test(character)).length,
        whitespaceCount: [...text].filter(character => /\s/.test(character)).length,
        otherCount: [...text].filter(character => !/[가-힣\s]/.test(character)).length,
      });
    }
    return result;
  }, index);
  const client = await page.context().newCDPSession(page);
  await client.send("DOM.enable");
  await client.send("CSS.enable");
  const documentNode = await client.send("DOM.getDocument", { depth: -1, pierce: true });
  const reports = [];
  for (const node of nodes) {
    const selected = await client.send("DOM.querySelector", { nodeId: documentNode.root.nodeId, selector: `[data-actual-font-id=\"${node.id}\"]` });
    if (!selected.nodeId) {
      reports.push({ ...node, fonts: [], evidenceMissing: true });
      continue;
    }
    const result = await client.send("CSS.getPlatformFontsForNode", { nodeId: selected.nodeId });
    const fonts = result.fonts
      .filter(font => font.glyphCount > 0)
      .map(font => ({ familyName: font.familyName, postScriptName: font.postScriptName, glyphCount: font.glyphCount, isCustomFont: font.isCustomFont }));
    reports.push({ ...node, fonts, evidenceMissing: node.hangulCount > 0 && !fonts.some(font => font.isCustomFont) });
  }
  await client.detach();
  await page.evaluate(slideIndex => {
    for (const element of document.querySelectorAll(`.slide:nth-of-type(${slideIndex + 1}) [data-actual-font-id]`)) element.removeAttribute("data-actual-font-id");
  }, index);
  return reports;
}

async function inspectViewport(browser, url, viewport, reducedMotion, expectedSlides, auditFonts) {
  const problems = [];
  const { context, page, assets } = await readyPage(browser, url, viewport, reducedMotion, problems);
  const initial = await page.evaluate(() => {
    const stage = document.querySelector(".deck-stage");
    if (!stage || !window.presentation) return null;
    const box = stage.getBoundingClientRect();
    return { slideCount: document.querySelectorAll(".slide").length, stageCss: [getComputedStyle(stage).width, getComputedStyle(stage).height], stageBox: [box.width, box.height] };
  });
  if (!initial) {
    problems.push("deck-controller-missing");
    await context.close();
    return { viewport, reducedMotion, problems, slideReports: [], assets, fontReports: [] };
  }
  if (initial.slideCount !== expectedSlides) problems.push(`slide-count:${initial.slideCount}:${expectedSlides}`);
  if (initial.stageCss[0] !== "1920px" || initial.stageCss[1] !== "1080px") problems.push(`stage-css:${initial.stageCss.join("x")}`);
  const factor = Math.min(viewport.width / 1920, viewport.height / 1080);
  if (Math.abs(initial.stageBox[0] - 1920 * factor) > 1 || Math.abs(initial.stageBox[1] - 1080 * factor) > 1) problems.push("stage-scale");

  const slideReports = [];
  const fontReports = [];
  for (let index = 0; index < initial.slideCount; index += 1) {
    await page.evaluate(value => window.presentation.showSlide(value), index);
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const report = await page.evaluate(slideIndex => {
      const slides = [...document.querySelectorAll(".slide")];
      const slide = slides[slideIndex];
      const slideBox = slide.getBoundingClientRect();
      const footer = slide.querySelector("deck-footer");
      const footerBox = footer?.getBoundingClientRect();
      const directTextElements = [...slide.querySelectorAll("*")].filter(element =>
        [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && (node.nodeValue || "").trim())
      );
      const explicitContainers = [...slide.querySelectorAll("table,pre,code,.loop-card,[data-overflow-check]")];
      const overflowCandidates = [...new Set([...directTextElements, ...explicitContainers])]
        .filter(element => !element.closest("[data-intentional-clip]") && !["auto", "scroll"].includes(getComputedStyle(element).overflowY) && (element.scrollWidth > element.clientWidth + 1 || element.scrollHeight > element.clientHeight + 1));
      const pseudoDecorativeOverflow = [];
      const visibleLineMetricOverflow = [];
      const textOverflow = [];
      for (const element of overflowCandidates) {
        const label = `${element.tagName}.${element.className || "-"}[${element.clientWidth}x${element.clientHeight}->${element.scrollWidth}x${element.scrollHeight}]`;
        const pseudo = getComputedStyle(element, "::after");
        const hasAfter = pseudo.content && pseudo.content !== "none" && pseudo.content !== "normal" && pseudo.display !== "none";
        const box = element.getBoundingClientRect();
        const directTextFits = [...element.childNodes]
          .filter(node => node.nodeType === Node.TEXT_NODE && (node.nodeValue || "").trim())
          .every(node => {
            const range = document.createRange();
            range.selectNodeContents(node);
            return [...range.getClientRects()].every(rect =>
              rect.left >= box.left - 1 && rect.right <= box.right + 1 && rect.top >= box.top - 1 && rect.bottom <= box.bottom + 1
            );
          });
        const childContentFits = [...element.children].every(child => {
          const childBox = child.getBoundingClientRect();
          return child.scrollWidth <= child.clientWidth + 1 && child.scrollHeight <= child.clientHeight + 1 &&
            childBox.left >= box.left - 1 && childBox.right <= box.right + 1 && childBox.top >= box.top - 1 && childBox.bottom <= box.bottom + 1;
        });
        if (hasAfter && directTextFits && childContentFits) pseudoDecorativeOverflow.push(label);
        else {
          const range = document.createRange();
          range.selectNodeContents(element);
          const oneLine = range.getClientRects().length === 1;
          const verticalOnly = element.scrollWidth <= element.clientWidth + 1 && element.scrollHeight > element.clientHeight + 1;
          const overflowY = getComputedStyle(element).overflowY;
          if (oneLine && verticalOnly && overflowY === "visible") visibleLineMetricOverflow.push(label);
          else textOverflow.push(label);
        }
      }
      const rawBoundedContent = [...new Set([
        ...directTextElements,
        ...slide.querySelectorAll("img,svg,canvas,video,table,pre,code,[data-boundary-check],[data-intentional-clip]"),
      ])].filter(element => element.getClientRects().length);
      const clippingAncestor = element => {
        for (let parent = element.parentElement; parent && parent !== slide; parent = parent.parentElement) {
          const style = getComputedStyle(parent);
          if (["hidden", "clip"].includes(style.overflowX) || ["hidden", "clip"].includes(style.overflowY)) return parent;
        }
        return null;
      };
      // A deliberately clipped image/text region is represented by its visible
      // clipping container. The container itself must still remain on-slide and
      // above the footer.
      const boundedContent = [...new Set(rawBoundedContent.map(element =>
        element.closest("[data-intentional-clip]") || clippingAncestor(element) || element
      ))];
      const outOfBounds = boundedContent.filter(element => {
        const box = element.getBoundingClientRect();
        return box.left < slideBox.left - 1 || box.right > slideBox.right + 1 || box.top < slideBox.top - 1 || box.bottom > slideBox.bottom + 1;
      }).map(element => `${element.tagName}.${element.className || "-"}`);
      const footerOverlap = footerBox ? boundedContent
        .filter(element => !element.closest("deck-footer") && element.getBoundingClientRect().bottom > footerBox.top + 1)
        .map(element => `${element.tagName}.${element.className || "-"}`) : [];
      const visible = slides.filter(element => getComputedStyle(element).visibility === "visible" && Number(getComputedStyle(element).opacity) > 0.5).length;
      return {
        index: slideIndex,
        active: slides.filter(element => element.classList.contains("active")).length,
        visibleClass: slides.filter(element => element.classList.contains("visible")).length,
        ariaVisible: slides.filter(element => element.getAttribute("aria-hidden") === "false").length,
        computedVisible: visible,
        textOverflow,
        pseudoDecorativeOverflow,
        visibleLineMetricOverflow,
        outOfBounds,
        footerOverlap,
      };
    }, index);
    for (const key of ["active", "visibleClass", "ariaVisible", "computedVisible"]) if (report[key] !== 1) problems.push(`single-slide:${index}:${key}:${report[key]}`);
    if (report.textOverflow.length) problems.push(`overflow:${index}:${report.textOverflow.join("|")}`);
    if (report.outOfBounds.length) problems.push(`out-of-bounds:${index}:${report.outOfBounds.join("|")}`);
    if (report.footerOverlap.length) problems.push(`footer-overlap:${index}:${report.footerOverlap.join("|")}`);
    slideReports.push(report);
    if (auditFonts) {
      const actualTextNodes = await auditActualTextFonts(page, index);
      for (const item of actualTextNodes) if (item.evidenceMissing) problems.push(`font-evidence-missing:${index}:${item.id}`);
      const hangulGlyphReports = await auditKoreanFonts(page, index);
      const hangulFallbacks = hangulGlyphReports.filter(item => item.fallback);
      for (const item of hangulFallbacks) problems.push(`font-fallback:${index}:U+${item.character.codePointAt(0).toString(16).toUpperCase()}:${item.family}`);
      fontReports.push({
        index,
        testedHangulGlyphs: hangulGlyphReports.length,
        hangulFallbacks,
        hangulGlyphReports,
        actualTextNodes,
        nonHangulOrUnresolvedSystemFontUsage: actualTextNodes
          .filter(item => item.fonts.some(font => !font.isCustomFont))
          .map(item => ({ id: item.id, whitespaceCount: item.whitespaceCount, otherCount: item.otherCount, systemFonts: item.fonts.filter(font => !font.isCustomFont) })),
      });
    }
  }
  await context.close();
  return { viewport, reducedMotion, problems, initial, slideReports, assets, fontReports };
}

function inspectPdf(pdfinfo, pdfPath, expectedSlides) {
  const result = spawnSync(pdfinfo, [pdfPath], { encoding: "utf8", windowsHide: true });
  if (result.status !== 0) return { problems: [`pdfinfo:${result.error?.code || result.status}`], pages: null, pageSizePoints: null };
  const pagesMatch = result.stdout.match(/^Pages:\s+(\d+)$/m);
  const sizeMatch = result.stdout.match(/^Page size:\s+([\d.]+) x ([\d.]+) pts/m);
  const pages = pagesMatch ? Number(pagesMatch[1]) : null;
  const pageSizePoints = sizeMatch ? [Number(sizeMatch[1]), Number(sizeMatch[2])] : null;
  const problems = [];
  if (pages !== expectedSlides) problems.push(`pdf-pages:${pages}:${expectedSlides}`);
  if (!pageSizePoints || Math.abs(pageSizePoints[0] / pageSizePoints[1] - 16 / 9) > 0.0001) problems.push(`pdf-ratio:${pageSizePoints}`);
  return { problems, pages, pageSizePoints };
}

async function main() {
  if (process.argv.includes("--help")) {
    console.log(usage());
    return 0;
  }
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.input) || !fs.statSync(args.input).isFile()) throw new Error(`Input not found: ${args.input}`);
  if (!args.input.toLowerCase().endsWith(".html")) throw new Error("--input must be HTML");
  if (!fs.existsSync(args.chrome)) throw new Error(`Chrome not found: ${args.chrome}`);
  if (fs.existsSync(args.outputDir)) throw new Error(`Output directory already exists: ${args.outputDir}`);
  fs.mkdirSync(args.outputDir, { recursive: true });
  const previewDir = path.join(args.outputDir, "previews");
  fs.mkdirSync(previewDir);

  const serverRoot = path.dirname(args.input);
  const server = await serve(serverRoot);
  // ?static=1은 셸의 GSAP 타임라인을 끝 상태로 보낸다. 검사와 캡처는 마지막 프레임 기준이다.
  const url = `http://127.0.0.1:${server.address().port}/${encodeURIComponent(path.basename(args.input))}?static=1`;
  let browser = null;
  let browserVersion = null;
  const checks = [];
  let pdfReport;
  const outputs = [];
  try {
    browser = await chromium.launch({ headless: true, executablePath: args.chrome });
    browserVersion = browser.version();
    checks.push(await inspectViewport(browser, url, { width: 1920, height: 1080 }, "no-preference", args.expectedSlides, true));
    checks.push(await inspectViewport(browser, url, { width: 1280, height: 720 }, "no-preference", args.expectedSlides, false));
    checks.push(await inspectViewport(browser, url, { width: 390, height: 844 }, "no-preference", args.expectedSlides, false));
    checks.push(await inspectViewport(browser, url, { width: 1920, height: 1080 }, "reduce", args.expectedSlides, false));

    const renderProblems = [];
    const rendered = await readyPage(browser, url, { width: 1920, height: 1080 }, "reduce", renderProblems);
    for (let index = 0; index < args.expectedSlides; index += 1) {
      await rendered.page.evaluate(value => window.presentation.showSlide(value), index);
      await rendered.page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const file = path.join(previewDir, `slide-${String(index + 1).padStart(String(args.expectedSlides).length, "0")}.png`);
      await rendered.page.screenshot({ path: file, animations: "disabled" });
      outputs.push({ path: path.relative(args.outputDir, file).replaceAll("\\", "/"), bytes: fs.statSync(file).size, sha256: sha256(file) });
    }
    checks.push({ viewport: { width: 1920, height: 1080 }, reducedMotion: "reduce", phase: "screenshots", problems: renderProblems });
    await rendered.context.close();

    const printProblems = [];
    const printable = await readyPage(browser, url, { width: 1920, height: 1080 }, "reduce", printProblems);
    await printable.page.emulateMedia({ media: "print", reducedMotion: "reduce" });
    await printable.page.addStyleTag({ content: RENDER_CSS });
    const pdfPath = path.join(args.outputDir, args.pdfName);
    await printable.page.pdf({ path: pdfPath, width: "1920px", height: "1080px", preferCSSPageSize: true, printBackground: true, margin: { top: 0, right: 0, bottom: 0, left: 0 }, timeout: 120000 });
    await printable.context.close();
    pdfReport = inspectPdf(args.pdfinfo, pdfPath, args.expectedSlides);
    pdfReport.problems.push(...printProblems);
    outputs.push({ path: path.relative(args.outputDir, pdfPath).replaceAll("\\", "/"), bytes: fs.statSync(pdfPath).size, sha256: sha256(pdfPath) });
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }

  const failures = checks.flatMap(check => check.problems.map(problem => ({ viewport: check.viewport, reducedMotion: check.reducedMotion, phase: check.phase || "inspect", problem })))
    .concat(pdfReport.problems.map(problem => ({ phase: "pdf", problem })));
  const report = {
    status: failures.length ? "failed" : "verified",
    input: args.input,
    inputSha256: sha256(args.input),
    expectedSlides: args.expectedSlides,
    chrome: args.chrome,
    browserVersion,
    checks,
    pdf: pdfReport,
    outputs,
    failures,
  };
  const reportPath = path.join(args.outputDir, "render-report.json");
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + "\n", "utf8");
  console.log(JSON.stringify({ status: report.status, slides: args.expectedSlides, fontFallbacks: failures.filter(item => item.problem.startsWith("font-fallback")).length, pdfPages: pdfReport.pages, failures: failures.length }));
  return failures.length ? 1 : 0;
}

main().then(code => { process.exitCode = code; }).catch(error => {
  console.error(JSON.stringify({ status: "failed", errorType: error.name, message: error.message }));
  process.exitCode = 1;
});
