import fs from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  MAX_AVATAR_BYTES,
  MAX_THEME_BYTES,
  loadRendererManifest,
  normalizeTheme,
  validateThemePackageManifest,
} from "./theme-contract.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const SKIN_VERSION = (await fs.readFile(path.join(root, "VERSION"), "utf8")).trim();
if (!SKIN_VERSION) throw new Error("VERSION is empty");
const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]"]);
const DEFAULT_THEME_ROOT = path.join(root, "themes", "builtin-miku-aqua");
const RENDERER = await loadRendererManifest(root);

function parseArgs(argv) {
  const options = {
    port: 9341,
    mode: "watch",
    timeoutMs: 30000,
    screenshot: null,
    reload: false,
    themeDir: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--port") options.port = Number(argv[++i]);
    else if (arg === "--once") options.mode = "once";
    else if (arg === "--watch") options.mode = "watch";
    else if (arg === "--verify") options.mode = "verify";
    else if (arg === "--remove") options.mode = "remove";
    else if (arg === "--check-payload") options.mode = "check";
    else if (arg === "--timeout-ms") options.timeoutMs = Number(argv[++i]);
    else if (arg === "--screenshot") options.screenshot = path.resolve(argv[++i]);
    else if (arg === "--theme-dir") options.themeDir = path.resolve(argv[++i]);
    else if (arg === "--reload") options.reload = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!Number.isInteger(options.port) || options.port < 1024 || options.port > 65535) {
    throw new Error(`Invalid port: ${options.port}`);
  }
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 250 || options.timeoutMs > 120000) {
    throw new Error(`Invalid timeout: ${options.timeoutMs}`);
  }
  return options;
}

function validatedDebuggerUrl(target, port) {
  const url = new URL(target.webSocketDebuggerUrl);
  if (url.protocol !== "ws:" || !LOOPBACK_HOSTS.has(url.hostname) || Number(url.port) !== port) {
    throw new Error(`Rejected non-loopback CDP WebSocket URL: ${url.href}`);
  }
  return url.href;
}

class CdpSession {
  constructor(target, port) {
    this.target = target;
    this.ws = new WebSocket(validatedDebuggerUrl(target, port));
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    this.closed = false;
  }

  async open() {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("CDP WebSocket open timed out")), 5000);
      this.ws.addEventListener("open", () => { clearTimeout(timeout); resolve(); }, { once: true });
      this.ws.addEventListener("error", () => { clearTimeout(timeout); reject(new Error("CDP WebSocket open failed")); }, { once: true });
    });
    this.ws.addEventListener("message", (event) => this.onMessage(event));
    this.ws.addEventListener("close", () => {
      this.closed = true;
      for (const waiter of this.pending.values()) {
        clearTimeout(waiter.timeout);
        waiter.reject(new Error("CDP socket closed"));
      }
      this.pending.clear();
    });
    await this.send("Runtime.enable");
    await this.send("Page.enable");
    return this;
  }

  onMessage(event) {
    const message = JSON.parse(String(event.data));
    if (message.id) {
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      clearTimeout(waiter.timeout);
      this.pending.delete(message.id);
      if (message.error) waiter.reject(new Error(`${message.error.message} (${message.error.code})`));
      else waiter.resolve(message.result);
      return;
    }
    for (const listener of this.listeners.get(message.method) ?? []) listener(message.params ?? {});
  }

  on(method, listener) {
    const listeners = this.listeners.get(method) ?? [];
    listeners.push(listener);
    this.listeners.set(method, listeners);
  }

  send(method, params = {}) {
    if (this.closed) return Promise.reject(new Error("CDP session is closed"));
    return new Promise((resolve, reject) => {
      const id = this.nextId++;
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`CDP command timed out: ${method}`));
      }, 10000);
      this.pending.set(id, { resolve, reject, timeout });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
      userGesture: false,
    });
    if (result.exceptionDetails) {
      const detail = result.exceptionDetails.exception?.description ?? result.exceptionDetails.text;
      throw new Error(`Renderer evaluation failed: ${detail}`);
    }
    return result.result?.value;
  }

  close() {
    if (!this.closed) this.ws.close();
    this.closed = true;
  }
}

async function listAppTargets(port) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2000);
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, { signal: controller.signal });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const targets = await response.json();
    return targets.filter((item) => {
      if (item.type !== "page" || !item.url?.startsWith("app://") || !item.webSocketDebuggerUrl) return false;
      try {
        validatedDebuggerUrl(item, port);
        return true;
      } catch {
        return false;
      }
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function probeSession(session) {
  return session.evaluate(`(() => {
    const markers = {
      shell: Boolean(document.querySelector('main.main-surface')),
      sidebar: Boolean(document.querySelector('aside.app-shell-left-panel')),
      composer: Boolean(document.querySelector('.composer-surface-chrome')),
      main: Boolean(document.querySelector('[role="main"], .thread-scroll-container')),
    };
    return {
      title: document.title,
      href: location.href,
      markers,
      codex: markers.shell && markers.sidebar && (markers.composer || markers.main),
    };
  })()`);
}

async function connectTarget(target, port) {
  return new CdpSession(target, port).open();
}

async function connectCodexTargets(port, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastError;
  while (Date.now() < deadline) {
    try {
      const targets = await listAppTargets(port);
      const connected = [];
      for (const target of targets) {
        let session;
        try {
          session = await connectTarget(target, port);
          const probe = await probeSession(session);
          if (probe?.codex) connected.push({ target, session, probe });
          else session.close();
        } catch (error) {
          session?.close();
          lastError = error;
        }
      }
      if (connected.length) return connected;
      lastError = new Error("No page matched the expected Codex shell markers");
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  throw new Error(`No verified Codex renderer on 127.0.0.1:${port}: ${lastError?.message ?? "timed out"}`);
}

async function loadTheme(themeDir) {
  let assetsRoot = DEFAULT_THEME_ROOT;
  if (themeDir) {
    try {
      await fs.access(path.join(themeDir, "theme.json"));
      assetsRoot = themeDir;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
  }

  const configPath = path.join(assetsRoot, "theme.json");
  const raw = JSON.parse(await fs.readFile(configPath, "utf8"));
  let packageManifest = null;
  try {
    packageManifest = JSON.parse(await fs.readFile(path.join(assetsRoot, "manifest.json"), "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  const theme = normalizeTheme(raw, {
    source: configPath,
    renderer: RENDERER,
    strict: Boolean(packageManifest),
  });
  if (packageManifest) {
    validateThemePackageManifest(packageManifest, {
      theme,
      renderer: RENDERER,
      engineVersion: SKIN_VERSION,
      source: path.join(assetsRoot, "manifest.json"),
    });
  }
  const imagePath = path.join(assetsRoot, theme.image);
  const imageStat = await fs.stat(imagePath);
  if (!imageStat.isFile() || imageStat.size < 1 || imageStat.size > MAX_THEME_BYTES) {
    throw new Error(`Theme image must be a non-empty file no larger than ${MAX_THEME_BYTES} bytes`);
  }
  return { assetsRoot, imagePath, imageStat, theme, packageManifest };
}

async function loadOptionalImageDataUrl(assetsRoot, filename) {
  if (!filename) return { bytes: 0, dataUrl: null };
  try {
    const file = path.join(assetsRoot, filename);
    const stat = await fs.stat(file);
    if (!stat.isFile() || stat.size < 1 || stat.size > MAX_AVATAR_BYTES) return { bytes: 0, dataUrl: null };
    const extension = path.extname(filename).toLowerCase();
    const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg"
      : extension === ".webp" ? "image/webp" : "image/png";
    const data = await fs.readFile(file);
    return { bytes: data.length, dataUrl: `data:${mime};base64,${data.toString("base64")}` };
  } catch (error) {
    if (error.code === "ENOENT") return { bytes: 0, dataUrl: null };
    throw error;
  }
}

async function loadPayload(themeDir) {
  const loaded = await loadTheme(themeDir);
  const { assetsRoot, imagePath, theme } = loaded;
  const layoutRenderer = RENDERER.layouts[theme.layoutId];
  const qqClassic = layoutRenderer.kind === "qq-classic";
  const [css, template] = await Promise.all([
    fs.readFile(layoutRenderer.stylesheet, "utf8"),
    fs.readFile(layoutRenderer.script, "utf8"),
  ]);
  const art = await fs.readFile(imagePath);
  const [userAvatar, assistantAvatar] = await Promise.all([
    loadOptionalImageDataUrl(assetsRoot, theme.avatars.user),
    loadOptionalImageDataUrl(assetsRoot, theme.avatars.assistant),
  ]);
  const extension = path.extname(imagePath).toLowerCase();
  const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg"
    : extension === ".webp" ? "image/webp" : "image/png";
  const artDataUrl = `data:${mime};base64,${art.toString("base64")}`;
  const runtimeTheme = {
    ...theme,
    rendererApiVersion: RENDERER.apiVersion,
    appearance: qqClassic ? "light" : undefined,
    explicitColorKeys: Object.keys(theme.colors),
    art: qqClassic ? { safeArea: "center", taskMode: "off" } : undefined,
    avatarDataUrls: {
      user: userAvatar.dataUrl,
      assistant: assistantAvatar.dataUrl,
    },
    layout: {
      mode: theme.layoutComponents.threePane ? "classic-three-pane" : "off",
      rightPanel: theme.layoutComponents.autoOpenSummary ? "open" : "remember",
      minWidth: theme.layoutComponents.minWidth,
      rightWidth: theme.layoutComponents.rightWidth,
    },
  };
  let payload;
  let layoutAssetBytes = 0;
  if (qqClassic) {
    const { pet: petPath, retroFrame: retroFramePath, avatar: avatarPath } = layoutRenderer.assets;
    if (!petPath || !retroFramePath || !avatarPath) throw new Error("QQ Classic renderer assets are incomplete.");
    const [pet, retroFrame, qqAvatar] = await Promise.all([
      fs.readFile(petPath),
      fs.readFile(retroFramePath),
      fs.readFile(avatarPath),
    ]);
    layoutAssetBytes = pet.length + retroFrame.length + qqAvatar.length;
    payload = template
      .replace("__QQ_SKIN_CSS_JSON__", JSON.stringify(css))
      .replace("__QQ_SKIN_ART_JSON__", JSON.stringify(artDataUrl))
      .replace("__QQ_SKIN_PET_JSON__", JSON.stringify(`data:image/png;base64,${pet.toString("base64")}`))
      .replace("__QQ_SKIN_RETRO_FRAME_JSON__", JSON.stringify(`data:image/png;base64,${retroFrame.toString("base64")}`))
      .replace("__QQ_SKIN_QQ_AVATAR_JSON__", JSON.stringify(`data:image/png;base64,${qqAvatar.toString("base64")}`))
      .replace("__QQ_SKIN_THEME_JSON__", JSON.stringify(runtimeTheme))
      .replace("__QQ_SKIN_VERSION_JSON__", JSON.stringify(SKIN_VERSION))
      .replace("__QQ_SKIN_STYLE_REVISION_JSON__", JSON.stringify(createHash("sha256").update(css).digest("hex").slice(0, 20)));
  } else {
    payload = template
      .replace("__DREAM_SKIN_CSS_JSON__", JSON.stringify(css))
      .replace("__DREAM_SKIN_ART_JSON__", JSON.stringify(artDataUrl))
      .replace("__DREAM_SKIN_THEME_JSON__", JSON.stringify(runtimeTheme))
      .replace("__DREAM_SKIN_VERSION_JSON__", JSON.stringify(SKIN_VERSION));
  }
  return {
    imageBytes: art.length,
    avatarBytes: { user: userAvatar.bytes, assistant: assistantAvatar.bytes },
    payload,
    theme,
    layoutAssetBytes,
  };
}

async function applyToSession(session, payload) {
  return session.evaluate(payload);
}

async function removeFromSession(session) {
  return session.evaluate(`(() => {
    window.__CODEX_DREAM_SKIN_DISABLED__ = true;
    window.__CODEX_QQ_SKIN_DISABLED__ = true;
    const dreamState = window.__CODEX_DREAM_SKIN_STATE__;
    const qqState = window.__CODEX_QQ_SKIN_STATE__;
    let removed = false;
    if (dreamState?.cleanup) removed = dreamState.cleanup() || removed;
    if (qqState?.cleanup) removed = qqState.cleanup() || removed;
    document.documentElement?.classList.remove('codex-dream-skin');
    document.documentElement?.classList.remove('codex-qq-skin');
    document.documentElement?.removeAttribute('data-dream-shell');
    document.documentElement?.removeAttribute('data-dream-theme');
    document.documentElement?.removeAttribute('data-dream-palette');
    document.documentElement?.style.removeProperty('--dream-skin-art');
    document.getElementById('codex-dream-skin-style')?.remove();
    document.getElementById('codex-dream-skin-chrome')?.remove();
    for (const id of ['codex-qq-skin-style', 'codex-qq-skin-chrome', 'codex-qq-skin-companion',
      'codex-qq-skin-home-pet', 'codex-qq-skin-right-tray', 'codex-qq-skin-retro-shell',
      'codex-qq-skin-retro-profile']) document.getElementById(id)?.remove();
    delete window.__CODEX_DREAM_SKIN_STATE__;
    delete window.__CODEX_QQ_SKIN_STATE__;
    return true;
  })()`);
}

async function verifyRemovedSession(session) {
  return session.evaluate(`(() =>
    !document.documentElement.classList.contains('codex-dream-skin') &&
    !document.documentElement.classList.contains('codex-qq-skin') &&
    !document.getElementById('codex-dream-skin-style') &&
    !document.getElementById('codex-dream-skin-chrome') &&
    !window.__CODEX_DREAM_SKIN_STATE__ && !window.__CODEX_QQ_SKIN_STATE__
  )()`);
}

async function verifySession(session) {
  return session.evaluate(`(() => {
    const box = (node, requirePaint = false) => {
      if (!node) return null;
      const r = node.getBoundingClientRect();
      const style = getComputedStyle(node);
      const center = r.width > 0 && r.height > 0
        ? document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2)
        : null;
      return {
        x: Math.round(r.x), y: Math.round(r.y),
        width: Math.round(r.width), height: Math.round(r.height),
        visible: r.width > 0 && r.height > 0 && style.display !== 'none' &&
          style.visibility !== 'hidden' && style.opacity !== '0' &&
          (!requirePaint || Boolean(center && node.contains(center))),
      };
    };
    const homeIndicator = document.querySelector('[data-testid="home-icon"]');
    const homeSignal = homeIndicator ?? document.querySelector('[data-feature="game-source"]') ??
      document.querySelector('.group\\\\/home-suggestions');
    const homeRoute = homeSignal?.closest('[role="main"]') ?? null;
    const home = document.querySelector('[role="main"].dream-skin-home');
    const suggestions = home?.querySelector('.group\\\\/home-suggestions') ?? null;
    const cardBoxes = suggestions ? [...suggestions.querySelectorAll('button')].map((node) => box(node, true)) : [];
    const visibleCards = cardBoxes.filter((item) => item?.visible);
    const hero = box(home?.firstElementChild?.firstElementChild?.firstElementChild, true);
    const projectButtonNode = home?.querySelector('.dream-skin-project-button') ??
      home?.querySelector('.group\\\\/project-selector > button') ??
      [...(home?.querySelectorAll('button, [role="button"]') ?? [])].find((candidate) => {
        const label = [candidate.getAttribute('aria-label'), candidate.getAttribute('title'), candidate.textContent]
          .filter(Boolean).join(' ')
          .replace(/\\s+/g, ' ').trim().toLowerCase();
        return label.includes('选择项目') || label.includes('select project') || label.includes('choose project');
      }) ?? null;
    const projectButton = box(projectButtonNode);
    const chatAvatarNodes = [...document.querySelectorAll('.dream-skin-chat-avatar')];
    const chatAvatars = {
      total: chatAvatarNodes.length,
      user: chatAvatarNodes.filter((node) => node.classList.contains('dream-skin-chat-avatar-user')).length,
      assistant: chatAvatarNodes.filter((node) => node.classList.contains('dream-skin-chat-avatar-assistant')).length,
      visible: chatAvatarNodes.filter((node) => box(node)?.visible).length,
    };
    const composer = box(document.querySelector('.composer-surface-chrome'));
    const sidebar = box(document.querySelector('aside.app-shell-left-panel'));
    const chrome = document.getElementById('codex-dream-skin-chrome');
    const threadPanel = document.querySelector('.thread-scroll-container');
    const threadStyle = threadPanel ? getComputedStyle(threadPanel) : null;
    const rootStyle = getComputedStyle(document.documentElement);
    const result = {
      installed: document.documentElement.classList.contains('codex-dream-skin') ||
        document.documentElement.classList.contains('codex-qq-skin'),
      layoutId: document.documentElement.classList.contains('codex-qq-skin') ? 'qq-classic' : 'stage',
      version: window.__CODEX_DREAM_SKIN_STATE__?.version ?? window.__CODEX_QQ_SKIN_STATE__?.version ?? null,
      visualStyle: window.__CODEX_DREAM_SKIN_STATE__?.visualStyle ?? null,
      paletteId: window.__CODEX_DREAM_SKIN_STATE__?.paletteId ?? null,
      effects: window.__CODEX_DREAM_SKIN_STATE__?.effects ?? null,
      headerText: window.__CODEX_DREAM_SKIN_STATE__?.headerText ?? null,
      renderedHeader: chrome ? {
        title: chrome.querySelector('.dream-skin-brand b')?.textContent ?? '',
        subtitle: chrome.querySelector('.dream-skin-brand small')?.textContent ?? '',
        status: chrome.querySelector('.dream-skin-status span')?.textContent ?? '',
      } : null,
      taskPanelStyle: threadStyle ? {
        opacity: rootStyle.getPropertyValue('--ds-task-panel-opacity').trim(),
        blur: rootStyle.getPropertyValue('--ds-task-panel-blur').trim(),
        backdropFilter: threadStyle.backdropFilter,
        backgroundImage: threadStyle.backgroundImage,
      } : null,
      stylePresent: Boolean(document.getElementById('codex-dream-skin-style') || document.getElementById('codex-qq-skin-style')),
      chromePresent: Boolean(chrome || document.getElementById('codex-qq-skin-chrome')),
      chromePointerEvents: getComputedStyle(chrome || document.getElementById('codex-qq-skin-chrome') || document.body).pointerEvents,
      homeRoute: Boolean(homeRoute),
      homePresent: Boolean(home),
      hero,
      cards: cardBoxes,
      visibleCardCount: visibleCards.length,
      projectButton,
      chatAvatars,
      composer,
      sidebar,
      viewport: { width: innerWidth, height: innerHeight },
      documentOverflow: {
        x: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        y: document.documentElement.scrollHeight > document.documentElement.clientHeight,
      },
    };
    const basePass = result.installed && result.version === ${JSON.stringify(SKIN_VERSION)} &&
      result.stylePresent && result.chromePresent && result.chromePointerEvents === 'none' &&
      Boolean(result.sidebar?.visible) && !result.documentOverflow.x &&
      (result.layoutId === 'qq-classic' || Boolean(result.composer?.visible));
    // Project selector markup varies across Codex builds — soft requirement.
    const homePass = !result.homeRoute || (
      result.homePresent && result.hero?.visible && result.hero.width >= 280 && result.hero.height >= 120 &&
      result.visibleCardCount >= 1 && result.visibleCardCount <= 6
    );
    result.pass = Boolean(basePass && homePass);
    result.softNotes = {
      projectButtonOptional: !result.projectButton?.visible,
    };
    return result;
  })()`);
}

async function waitForVerifiedSession(session, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastResult;
  while (Date.now() < deadline) {
    lastResult = await verifySession(session);
    if (lastResult.pass) return lastResult;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return lastResult;
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await session.send("Input.dispatchKeyEvent", { type: "keyDown", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  await session.send("Input.dispatchKeyEvent", { type: "keyUp", key: "Escape", code: "Escape", windowsVirtualKeyCode: 27 });
  const viewport = await session.evaluate("({ width: innerWidth, height: innerHeight })");
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseMoved",
    x: Math.round(viewport.width * 0.64),
    y: Math.round(viewport.height * 0.62),
    button: "none",
  });
  await new Promise((resolve) => setTimeout(resolve, 300));
  const result = await session.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: false,
  });
  await fs.writeFile(outputPath, Buffer.from(result.data, "base64"));
}

async function runOneShot(options) {
  const connected = await connectCodexTargets(options.port, options.timeoutMs);
  const loaded = (options.mode === "once" || options.reload) ? await loadPayload(options.themeDir) : null;
  const payload = loaded?.payload ?? null;
  const results = [];
  let screenshotCaptured = false;

  for (const { target, session, probe } of connected) {
    try {
      if (options.mode === "remove") await removeFromSession(session);
      else if (options.mode === "once") await applyToSession(session, payload);

      if (options.reload) {
        await session.send("Page.reload", { ignoreCache: true });
        await new Promise((resolve) => setTimeout(resolve, 1600));
        if (options.mode !== "remove") await applyToSession(session, payload);
      }

      const result = options.mode === "remove"
        ? await verifyRemovedSession(session)
        : await waitForVerifiedSession(session, options.timeoutMs);
      results.push({ targetId: target.id, title: target.title, url: target.url, probe, result });

      if (options.screenshot && !screenshotCaptured) {
        await capture(session, options.screenshot);
        screenshotCaptured = true;
      }
    } finally {
      session.close();
    }
  }

  console.log(JSON.stringify({ mode: options.mode, version: SKIN_VERSION, port: options.port, targets: results }, null, 2));
  const failed = results.length === 0 || results.some((item) => options.mode === "remove" ? item.result !== true : !item.result?.pass);
  if (failed) process.exitCode = 2;
}

async function runWatch(options) {
  const { payload } = await loadPayload(options.themeDir);
  const sessions = new Map();
  const rejected = new Set();
  let stopping = false;
  const stop = () => { stopping = true; };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);

  while (!stopping) {
    let targets = [];
    try {
      targets = await listAppTargets(options.port);
    } catch (error) {
      console.error(`[dream-skin] ${new Date().toISOString()} ${error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 1000));
      continue;
    }

    const activeIds = new Set(targets.map((target) => target.id));
    for (const [id, session] of sessions) {
      if (!activeIds.has(id) || session.closed) {
        session.close();
        sessions.delete(id);
      }
    }

    for (const target of targets) {
      if (sessions.has(target.id)) continue;
      let session;
      try {
        session = await connectTarget(target, options.port);
        const probe = await probeSession(session);
        if (!probe?.codex) {
          session.close();
          if (!rejected.has(target.id)) {
            console.error(`[dream-skin] rejected non-Codex app target ${target.id}`);
            rejected.add(target.id);
          }
          continue;
        }
        rejected.delete(target.id);
        session.on("Page.loadEventFired", () => {
          setTimeout(() => applyToSession(session, payload).catch((error) => {
            console.error(`[dream-skin] reinject failed: ${error.message}`);
          }), 250);
        });
        await applyToSession(session, payload);
        sessions.set(target.id, session);
        console.log(`[dream-skin] injected verified Codex target ${target.id} (${target.title || target.url})`);
      } catch (error) {
        session?.close();
        console.error(`[dream-skin] inject failed for ${target.id}: ${error.message}`);
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 900));
  }

  for (const session of sessions.values()) session.close();
}

let watchMode = false;
try {
  const options = parseArgs(process.argv.slice(2));
  watchMode = options.mode === "watch";
  if (options.mode === "check") {
    const loaded = await loadPayload(options.themeDir);
    console.log(JSON.stringify({
      pass: true,
      version: SKIN_VERSION,
      themeId: loaded.theme.id,
      themeName: loaded.theme.name,
      visualStyle: loaded.theme.visualStyle,
      layoutId: loaded.theme.layoutId,
      layoutComponents: loaded.theme.layoutComponents,
      paletteId: loaded.theme.paletteId,
      paletteName: loaded.theme.paletteName,
      backgroundName: loaded.theme.backgroundName,
      effects: loaded.theme.effects,
      headerText: loaded.theme.headerText,
      imageBytes: loaded.imageBytes,
      avatarBytes: loaded.avatarBytes,
      layoutAssetBytes: loaded.layoutAssetBytes,
      payloadBytes: Buffer.byteLength(loaded.payload),
    }, null, 2));
  } else if (options.mode === "watch") {
    await runWatch(options);
    watchMode = false;
  }
  else await runOneShot(options);
} catch (error) {
  console.error(`[dream-skin] ${error.stack || error.message}`);
  process.exitCode = 1;
}

// Node's built-in WebSocket can keep a CDP connection alive while waiting for
// a peer close frame, even after a one-shot result has already been printed.
// Watch mode is intentionally long-lived; every other mode must finish now.
if (!watchMode) {
  await Promise.all([process.stdout, process.stderr].map((stream) =>
    new Promise((resolve) => stream.write("", resolve))));
  process.exit(process.exitCode ?? 0);
}
