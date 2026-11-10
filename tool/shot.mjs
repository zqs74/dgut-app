#!/usr/bin/env node
/**
 * dgut_app 视觉验证：起一个 Chrome，打开 build/web，滚到指定位置截图。
 *
 *   node tool/shot.mjs <url> <out.png> [--w 420] [--h 900] [--scroll 0,120,260]
 *                      [--wait 2200] [--tap "x,y"] [--hold 900]
 *
 * --scroll  依次下滚的像素量，每步之间等 420ms，最后一张图是终态
 * --tap     在坐标处按下（用于看 dock 的按压态）
 * --hold    按住多少毫秒后截图
 */
import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const argv = process.argv.slice(2);
const url = argv[0];
const out = argv[1];
const opt = (name, fallback) => {
  const i = argv.indexOf("--" + name);
  return i > -1 ? argv[i + 1] : fallback;
};
const W = Number(opt("w", 420));
const H = Number(opt("h", 900));
const WAIT = Number(opt("wait", 2200));
const scrolls = String(opt("scroll", "0"))
  .split(",")
  .map((s) => Number(s.trim()))
  .filter((n) => !Number.isNaN(n));
const tap = opt("tap", "");
const drag = opt("drag", "");
const click = opt("click", "");
const hold = Number(opt("hold", 700));

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PORT = 9900 + (process.pid % 90);
const profile = mkdtempSync(join(tmpdir(), "dgut-shot-"));
const chrome = spawn(
  CHROME,
  [
    "--headless=new",
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profile}`,
    "--no-first-run",
    "--hide-scrollbars",
    "--allow-file-access-from-files",
    `--window-size=${W},${H}`,
    "about:blank",
  ],
  { stdio: "ignore" }
);

let wsUrl;
for (let i = 0; i < 120 && !wsUrl; i++) {
  try {
    const j = await (await fetch(`http://127.0.0.1:${PORT}/json/version`)).json();
    wsUrl = j.webSocketDebuggerUrl;
  } catch {}
  if (!wsUrl) await sleep(150);
}
if (!wsUrl) {
  console.error("chrome 未就绪");
  process.exit(1);
}

const ws = new WebSocket(wsUrl);
await new Promise((r, j) => {
  ws.onopen = r;
  ws.onerror = j;
});
let seq = 0;
const pending = new Map();
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.method === 'Runtime.exceptionThrown') {
    const d = m.params?.exceptionDetails;
    console.log('[flutter-exception]', d?.text, d?.exception?.description || '');
  }
  if (m.method === 'Runtime.consoleAPICalled' && m.params?.type === 'error') {
    console.log('[console.error]', (m.params.args || []).map(a => a.value ?? a.description ?? '').join(' '));
  }
  if (m.id && pending.has(m.id)) {
    pending.get(m.id)(m);
    pending.delete(m.id);
  }
};
const send = (method, params = {}, sessionId) => {
  const id = ++seq;
  ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  return new Promise((res, rej) =>
    pending.set(id, (m) => (m.error ? rej(new Error(method + ": " + m.error.message)) : res(m.result)))
  );
};

const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
await send("Page.enable", {}, sessionId);
await send("Runtime.enable", {}, sessionId);
await send("Network.enable", {}, sessionId);
// Flutter web 的 service worker 会缓存上一版 main.dart.js，并在后台自刷 —— 截图会踩到旧包或刷新的瞬间
await send("Network.setBypassServiceWorker", { bypass: true }, sessionId);
await send("Network.setCacheDisabled", { cacheDisabled: true }, sessionId);
await send(
  "Emulation.setDeviceMetricsOverride",
  { width: W, height: H, deviceScaleFactor: 2, mobile: true },
  sessionId
);
await send("Page.navigate", { url }, sessionId);
if (argv.includes("--dark")) {
  await send(
    "Emulation.setEmulatedMedia",
    { features: [{ name: "prefers-color-scheme", value: "dark" }] },
    sessionId
  );
}
await sleep(WAIT);

const wheel = async (x, y, dy) => {
  // Flutter web 只认"指针在画布上"之后的滚轮，先移进去
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y, pointerType: "mouse" }, sessionId);
  await sleep(80);
  // 一次发完整 delta：拆成小步会让每步重新起一次滚动，累计位移会丢
  await send(
    "Input.dispatchMouseEvent",
    { type: "mouseWheel", x, y, deltaX: 0, deltaY: dy, pointerType: "mouse" },
    sessionId
  );
  await sleep(1400);
};

let total = 0;
for (const s of scrolls) {
  if (s > total) await wheel(W / 2, H * 0.45, s - total);
  else if (s < total) await wheel(W / 2, H * 0.45, s - total);
  total = s;
}

if (tap) {
  const [tx, ty] = tap.split(",").map(Number);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: tx, y: ty }, sessionId);
  await sleep(60);
  await send(
    "Input.dispatchMouseEvent",
    { type: "mousePressed", x: tx, y: ty, button: "left", buttons: 1, clickCount: 1 },
    sessionId
  );
  await sleep(hold);
}

if (click) {
  const [cx, cy] = click.split(",").map(Number);
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: cx, y: cy, pointerType: "mouse" }, sessionId);
  await sleep(60);
  await send(
    "Input.dispatchMouseEvent",
    { type: "mousePressed", x: cx, y: cy, button: "left", buttons: 1, clickCount: 1 },
    sessionId
  );
  await sleep(90);
  await send(
    "Input.dispatchMouseEvent",
    { type: "mouseReleased", x: cx, y: cy, button: "left", buttons: 0, clickCount: 1 },
    sessionId
  );
  await sleep(1200);
}

// --drag "x,y,dy"：用触摸拖动精确滚动，比滚轮稳（滚轮的像素换算不固定）
if (drag) {
  const [dx0, dy0, ddy] = drag.split(",").map(Number);
  await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 1 }, sessionId);
  await sleep(120);
  await send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: dx0, y: dy0 }] }, sessionId);
  const steps = 16;
  for (let i = 1; i <= steps; i++) {
    await send(
      "Input.dispatchTouchEvent",
      { type: "touchMove", touchPoints: [{ x: dx0, y: dy0 + (ddy * i) / steps }] },
      sessionId
    );
    await sleep(16);
  }
  await send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] }, sessionId);
  await sleep(800);
}
const png = await send("Page.captureScreenshot", { format: "png" }, sessionId);
writeFileSync(out, Buffer.from(png.data, "base64"));
console.log("shot:", out, `${W}x${H}`, "scroll=" + total, tap ? "tap=" + tap : "");

try {
  ws.close();
} catch {}
chrome.kill();
await sleep(250);
try {
  rmSync(profile, { recursive: true, force: true });
} catch {}
