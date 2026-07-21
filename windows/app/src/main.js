const { app, BrowserWindow, dialog, ipcMain, Menu, nativeImage, Notification, shell, Tray } = require("electron");
const fs = require("node:fs/promises");
const net = require("node:net");
const path = require("node:path");
const { execFile, spawn } = require("node:child_process");
const { promisify } = require("node:util");
const { ThemeService } = require("./theme-service");

const execFileAsync = promisify(execFile);
const DEFAULT_STORE_URL = "http://skin.beadplay.cn";
const LOOPBACK = "127.0.0.1";
const DEFAULT_PORT = 9341;

let tray;
let editorWindow;
let themeService;
let engineRoot;
let stateRoot;
let statePath;
let busy = false;

function localAppDataPath() {
  return process.env.LOCALAPPDATA || path.join(app.getPath("home"), "AppData", "Local");
}

function loginExecutable() {
  return process.env.PORTABLE_EXECUTABLE_FILE || process.execPath;
}

function themeStoreUrl() {
  try {
    const value = new URL(process.env.CODEX_DREAM_SKIN_STORE_URL || DEFAULT_STORE_URL);
    if (value.protocol === "http:" || value.protocol === "https:") return value.href;
  } catch {}
  return DEFAULT_STORE_URL;
}

function iconPath() {
  return path.join(__dirname, "../build/icon.png");
}

function showNotification(title, body) {
  if (Notification.isSupported()) new Notification({ title, body, icon: iconPath() }).show();
}

async function runPowerShell(script, timeout = 15000) {
  const { stdout } = await execFileAsync("powershell.exe", [
    "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", script,
  ], { encoding: "utf8", timeout, windowsHide: true, maxBuffer: 2 * 1024 * 1024 });
  return stdout.trim();
}

async function discoverCodexExecutable() {
  const output = await runPowerShell(`
    $pkg = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pkg) { exit 3 }
    $candidates = @(
      (Join-Path $pkg.InstallLocation 'app\\ChatGPT.exe'),
      (Join-Path $pkg.InstallLocation 'app\\Codex.exe')
    )
    $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) { exit 4 }
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $exe
  `);
  if (!output) throw new Error("未找到 Microsoft Store 安装的 Codex Desktop。");
  return output.split(/\r?\n/).at(-1).trim();
}

async function isCodexRunning() {
  return (await runPowerShell("if (Get-Process ChatGPT -ErrorAction SilentlyContinue) { 'true' } else { 'false' }").catch(() => "false")) === "true";
}

async function stopCodex() {
  await runPowerShell("Get-Process ChatGPT -ErrorAction SilentlyContinue | Stop-Process -Force", 15000);
  await new Promise((resolve) => setTimeout(resolve, 700));
}

function launchExecutable(executable, args = []) {
  const child = spawn(executable, args, { detached: true, stdio: "ignore", windowsHide: false });
  child.unref();
}

async function listTargets(port) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 1200);
  try {
    const response = await fetch(`http://${LOOPBACK}:${port}/json/list`, { signal: controller.signal });
    if (!response.ok) return [];
    const targets = await response.json();
    return targets.filter((target) => target.type === "page" && target.url?.startsWith("app://"));
  } catch {
    return [];
  } finally {
    clearTimeout(timer);
  }
}

async function cdpReady(port) {
  return (await listTargets(port)).length > 0;
}

async function readState() {
  try {
    return JSON.parse(await fs.readFile(statePath, "utf8"));
  } catch {
    return { session: "off", port: DEFAULT_PORT };
  }
}

async function writeState(next) {
  await fs.mkdir(path.dirname(statePath), { recursive: true });
  const temporary = `${statePath}.${process.pid}.tmp`;
  await fs.writeFile(temporary, `${JSON.stringify(next, null, 2)}\n`);
  await fs.rm(statePath, { force: true });
  await fs.rename(temporary, statePath);
  return next;
}

function processAlive(pid) {
  if (!Number.isInteger(Number(pid)) || Number(pid) <= 0) return false;
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch {
    return false;
  }
}

async function isOwnedWatcher(pid, expectedScript) {
  const value = Number(pid);
  if (!Number.isInteger(value) || value <= 0 || !expectedScript || !processAlive(value)) return false;
  const escapedScript = String(expectedScript).replace(/'/g, "''");
  const result = await runPowerShell(`
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = ${value}" -ErrorAction SilentlyContinue
    if ($process -and $process.CommandLine.Contains('${escapedScript}') -and $process.CommandLine -match '--watch') { 'true' } else { 'false' }
  `).catch(() => "false");
  return result === "true";
}

async function findFreePort(start = DEFAULT_PORT) {
  for (let port = start; port < start + 30; port += 1) {
    const free = await new Promise((resolve) => {
      const server = net.createServer();
      server.once("error", () => resolve(false));
      server.listen(port, LOOPBACK, () => server.close(() => resolve(true)));
    });
    if (free) return port;
  }
  throw new Error("未找到可用的本机 CDP 端口。");
}

function nodeScript(script, args, options = {}) {
  const executable = process.execPath;
  const env = { ...process.env, ELECTRON_RUN_AS_NODE: "1" };
  return spawn(executable, [script, ...args], {
    env,
    windowsHide: true,
    stdio: options.stdio || ["ignore", "pipe", "pipe"],
    detached: Boolean(options.detached),
  });
}

async function runInjector(args, timeout = 45000) {
  const script = path.join(engineRoot, "scripts", "injector.mjs");
  return new Promise((resolve, reject) => {
    const child = nodeScript(script, args);
    let output = "";
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error("主题引擎操作超时。"));
    }, timeout);
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    child.once("error", (error) => { clearTimeout(timer); reject(error); });
    child.once("exit", (code) => {
      clearTimeout(timer);
      if (code === 0) resolve(output.trim());
      else reject(new Error(output.trim().slice(-1200) || `主题引擎退出码：${code}`));
    });
  });
}

async function stopWatcher() {
  const state = await readState();
  if (await isOwnedWatcher(state.injectorPid, state.injectorScript)) {
    try { process.kill(Number(state.injectorPid)); } catch {}
  }
  return state;
}

async function startWatcher(port) {
  const state = await stopWatcher();
  const log = path.join(themeService.logsDir, "injector.log");
  const errorLog = path.join(themeService.logsDir, "injector-error.log");
  const [stdout, stderr] = await Promise.all([fs.open(log, "a"), fs.open(errorLog, "a")]);
  const script = path.join(engineRoot, "scripts", "injector.mjs");
  const child = nodeScript(script, ["--watch", "--port", String(port), "--theme-dir", themeService.activeDir], {
    detached: true,
    stdio: ["ignore", stdout.fd, stderr.fd],
  });
  child.unref();
  await Promise.all([stdout.close(), stderr.close()]);
  await writeState({ ...state, session: "active", port, injectorPid: child.pid, injectorScript: script, startedAt: new Date().toISOString() });
  return child.pid;
}

async function waitForCdp(port, timeout = 30000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (await cdpReady(port)) return;
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error(`Codex 未在 30 秒内开放本机端口 ${port}。`);
}

async function currentStatus() {
  const state = await readState();
  const theme = await themeService.loadTheme().catch(() => ({
    name: "", paletteId: "", paletteName: "", backgroundName: "", layoutId: "stage", effects: { taskPanelOpacity: 0.76, taskPanelBlur: 14 },
  }));
  const cdpOk = await cdpReady(Number(state.port || DEFAULT_PORT));
  const injectorAlive = await isOwnedWatcher(state.injectorPid, state.injectorScript);
  let skinVerified = false;
  if (cdpOk && injectorAlive) {
    skinVerified = await runInjector([
      "--verify", "--port", String(state.port), "--timeout-ms", "1200",
    ], 5000).then(() => true).catch(() => false);
  }
  return {
    session: state.session === "paused" ? "paused" : skinVerified ? "active" : state.session === "active" ? "stale" : "off",
    port: Number(state.port || DEFAULT_PORT),
    cdpOk,
    injectorAlive,
    skinVerified,
    codexRunning: await isCodexRunning(),
    themeName: theme.name,
    paletteId: theme.paletteId,
    paletteName: theme.paletteName,
    backgroundName: theme.backgroundName,
    layoutId: theme.layoutId,
    taskPanelOpacityPercent: Math.round((theme.effects?.taskPanelOpacity ?? 0.76) * 100),
    taskPanelBlur: theme.effects?.taskPanelBlur ?? 14,
  };
}

async function applySkin({ promptForRestart = true } = {}) {
  let state = await readState();
  let port = Number(state.port || DEFAULT_PORT);
  const reusableSession = state.session !== "off" && await cdpReady(port);
  if (!reusableSession) {
    if (await isCodexRunning()) {
      if (!promptForRestart) throw new Error("Codex 已在运行，但没有启用本机 CDP。");
      const response = await dialog.showMessageBox({
        type: "question",
        title: "需要重启 Codex",
        message: "当前 Codex 未启用主题所需的本机 CDP。是否立即重启 Codex 并应用皮肤？",
        detail: "不会修改 WindowsApps、app.asar、签名、账户或 API 配置。",
        buttons: ["重启并应用", "取消"],
        defaultId: 0,
        cancelId: 1,
        noLink: true,
      });
      if (response.response !== 0) return false;
      await stopCodex();
    }
    port = await findFreePort(DEFAULT_PORT);
    const executable = await discoverCodexExecutable();
    launchExecutable(executable, [`--remote-debugging-address=${LOOPBACK}`, `--remote-debugging-port=${port}`]);
    await waitForCdp(port);
  }
  await runInjector(["--once", "--port", String(port), "--theme-dir", themeService.activeDir]);
  await startWatcher(port);
  await writeState({ ...(await readState()), session: "active", port });
  return true;
}

async function pauseSkin() {
  const state = await stopWatcher();
  const port = Number(state.port || DEFAULT_PORT);
  if (await cdpReady(port)) {
    await runInjector(["--remove", "--port", String(port), "--timeout-ms", "5000"], 10000).catch(() => {});
  }
  await writeState({ ...state, session: "paused", injectorPid: null });
}

async function restoreLegacyAppearance() {
  const legacyRoot = path.join(localAppDataPath(), "CodexDreamSkin");
  const backup = path.join(legacyRoot, "config.before-dream-skin.toml");
  const config = path.join(app.getPath("home"), ".codex", "config.toml");
  if (!(await fs.access(backup).then(() => true).catch(() => false))) return false;
  const [saved, current] = await Promise.all([fs.readFile(backup, "utf8"), fs.readFile(config, "utf8")]);
  let next = current;
  for (const key of ["appearanceTheme", "appearanceLightCodeThemeId", "appearanceLightChromeTheme"]) {
    const pattern = new RegExp(`^${key}\\s*=.*(?:\\r?\\n)?`, "m");
    const savedMatch = saved.match(pattern);
    if (pattern.test(next)) next = next.replace(pattern, savedMatch?.[0] || "");
  }
  await fs.writeFile(config, next);
  return true;
}

async function restoreOfficial() {
  const response = await dialog.showMessageBox({
    type: "warning",
    title: "完全恢复官方外观",
    message: "停止主题、恢复旧版安装器备份的外观设置，并以普通模式重启 Codex？",
    detail: "主题库和背景图片会保留。不会修改 WindowsApps、app.asar、账户或 API 配置。",
    buttons: ["恢复并重启", "取消"],
    defaultId: 1,
    cancelId: 1,
    noLink: true,
  });
  if (response.response !== 0) return false;
  await pauseSkin();
  await restoreLegacyAppearance();
  if (await isCodexRunning()) await stopCodex();
  launchExecutable(await discoverCodexExecutable());
  await writeState({ ...(await readState()), session: "off", injectorPid: null });
}

async function withBusy(label, action) {
  if (busy) return;
  busy = true;
  await rebuildTrayMenu();
  try {
    const result = await action();
    if (result !== false) showNotification("Codex Dream Skin", `${label}完成`);
  } catch (error) {
    await dialog.showMessageBox({ type: "error", title: `${label}失败`, message: error.message || String(error) });
  } finally {
    busy = false;
    await rebuildTrayMenu();
  }
}

function statusLabel(session) {
  return ({ active: "皮肤已启用", paused: "皮肤已暂停", stale: "需要重新应用", off: "皮肤未启用" })[session] || "状态未知";
}

async function quickBackground() {
  const result = await dialog.showOpenDialog({
    title: "选择主题背景图片",
    properties: ["openFile"],
    filters: [{ name: "图片", extensions: ["png", "jpg", "jpeg", "webp"] }],
  });
  if (result.canceled || !result.filePaths[0]) return false;
  await themeService.addBackground(result.filePaths[0]);
  return applySkin();
}

async function importThemePackage() {
  const result = await dialog.showOpenDialog({
    title: "导入 Codex Dream Skin 主题包",
    properties: ["openFile"],
    filters: [{ name: "Codex Dream Skin 主题包", extensions: ["zip"] }],
  });
  if (result.canceled || !result.filePaths[0]) return false;
  await themeService.importPackage(result.filePaths[0]);
  return applySkin();
}

async function exportThemePackage() {
  const theme = await themeService.loadTheme();
  const result = await dialog.showSaveDialog({
    title: "导出当前主题",
    defaultPath: `${theme.name.replace(/[\\/:*?\"<>|]/g, "-") || "Codex-Dream-Skin-Theme"}.cds-theme.zip`,
    filters: [{ name: "Codex Dream Skin 主题包", extensions: ["zip"] }],
  });
  if (result.canceled || !result.filePath) return false;
  const output = result.filePath.toLowerCase().endsWith(".zip") ? result.filePath : `${result.filePath}.zip`;
  await themeService.exportPackage(output);
  shell.showItemInFolder(output);
  return true;
}

async function rebuildTrayMenu() {
  if (!tray) return;
  const [status, choices, version] = await Promise.all([currentStatus(), themeService.choices(), themeService.version()]);
  const choiceMenu = (items, selected, action) => items.map((item) => ({
    label: item.name,
    type: "radio",
    checked: item.id === selected,
    enabled: !busy,
    click: () => withBusy("切换主题", async () => { await action(item.id); return applySkin(); }),
  }));
  const paletteItems = choices.palettes.filter((item) => (item.layoutId || "stage") === status.layoutId);
  const template = [
    { label: `状态：${busy ? "正在处理..." : statusLabel(status.session)}`, enabled: false },
    { label: `${status.themeName || "当前主题"} · ${status.paletteName || status.layoutId}`, enabled: false },
    { type: "separator" },
    { label: "应用皮肤", enabled: !busy, click: () => withBusy("应用皮肤", applySkin) },
    { label: "暂停皮肤", enabled: !busy && status.session !== "off", click: () => withBusy("暂停皮肤", pauseSkin) },
    { label: "打开主题工作室", enabled: !busy, click: openEditor },
    { label: "打开主题商店", enabled: !busy, click: () => shell.openExternal(themeStoreUrl()) },
    { type: "separator" },
    { label: "导入主题包", enabled: !busy, click: () => withBusy("导入主题包", importThemePackage) },
    { label: "导出当前主题", enabled: !busy, click: () => withBusy("导出主题包", exportThemePackage) },
    { label: "快速换背景图", enabled: !busy, click: () => withBusy("更换背景", quickBackground) },
    { label: "布局主题", submenu: choiceMenu(choices.layouts, status.layoutId, (id) => themeService.switchLayout(id)) },
    { label: "配色方案", submenu: choiceMenu(paletteItems, status.paletteId, (id) => themeService.switchPalette(id)) },
    { label: "背景图片", submenu: [
      ...choiceMenu(choices.backgrounds, status.backgroundName, (id) => themeService.switchBackground(id)),
      { type: "separator" },
      { label: "打开背景文件夹", click: () => shell.openPath(themeService.imagesDir) },
    ] },
    ...(choices.themes.length ? [{ label: "历史组合", submenu: choiceMenu(choices.themes, "", (id) => themeService.switchHistoricalTheme(id)) }] : []),
    { type: "separator" },
    { label: "完全恢复官方外观", enabled: !busy, click: () => withBusy("恢复官方外观", restoreOfficial) },
    { label: "打开日志文件夹", click: () => shell.openPath(themeService.logsDir) },
    {
      label: "登录时启动",
      type: "checkbox",
      checked: app.getLoginItemSettings({ path: loginExecutable(), args: ["--hidden"] }).openAtLogin,
      click: (item) => app.setLoginItemSettings({ openAtLogin: item.checked, path: loginExecutable(), args: ["--hidden"] }),
    },
    { type: "separator" },
    { label: `关于 Codex Dream Skin ${version}`, click: () => dialog.showMessageBox({
      type: "info",
      title: "Codex Dream Skin",
      message: `Codex Dream Skin ${version}`,
      detail: "非 OpenAI 官方产品。通过 127.0.0.1 回环 CDP 应用主题，不修改 WindowsApps、app.asar、代码签名或 API 配置。",
    }) },
    { label: "退出托盘应用", role: "quit" },
  ];
  tray.setContextMenu(Menu.buildFromTemplate(template));
  tray.setToolTip(`Codex Dream Skin · ${statusLabel(status.session)}`);
}

function createEditorWindow() {
  const window = new BrowserWindow({
    width: 1080,
    height: 760,
    minWidth: 860,
    minHeight: 640,
    show: false,
    backgroundColor: "#111518",
    title: "Codex Dream Skin 主题工作室",
    icon: iconPath(),
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  window.removeMenu();
  window.loadFile(path.join(__dirname, "renderer", "theme-studio.html"));
  window.webContents.setWindowOpenHandler(() => ({ action: "deny" }));
  window.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith("file:")) event.preventDefault();
  });
  window.once("ready-to-show", () => window.show());
  window.on("closed", () => { editorWindow = null; });
  return window;
}

function openEditor() {
  if (!editorWindow) editorWindow = createEditorWindow();
  else {
    editorWindow.show();
    editorWindow.focus();
  }
}

async function selectImage(title, maxBytes) {
  const result = await dialog.showOpenDialog(editorWindow || undefined, {
    title,
    properties: ["openFile"],
    filters: [{ name: "图片", extensions: ["png", "jpg", "jpeg", "webp"] }],
  });
  if (result.canceled || !result.filePaths[0]) return null;
  const file = result.filePaths[0];
  const stat = await fs.stat(file);
  if (stat.size > maxBytes) throw new Error(`图片不能超过 ${Math.round(maxBytes / 1024 / 1024)} MB。`);
  const data = await fs.readFile(file);
  const extension = path.extname(file).toLowerCase();
  const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg" : extension === ".webp" ? "image/webp" : "image/png";
  return { path: file, dataUrl: `data:${mime};base64,${data.toString("base64")}` };
}

function registerIpc() {
  ipcMain.handle("studio:load", async () => ({
    theme: await themeService.activeThemeView(),
    choices: await themeService.choices(),
    status: await currentStatus(),
    version: await themeService.version(),
  }));
  ipcMain.handle("studio:choose-background", () => selectImage("选择主题背景图片", 16 * 1024 * 1024));
  ipcMain.handle("studio:choose-avatar", (_event, role) => selectImage(role === "user" ? "选择我的提问头像" : "选择 Codex 回答头像", 4 * 1024 * 1024));
  ipcMain.handle("studio:save", async (_event, draft, applyImmediately) => {
    const theme = await themeService.saveDraft(draft);
    let applied = null;
    let applyError = null;
    if (applyImmediately) {
      try {
        applied = await applySkin();
      } catch (error) {
        applied = false;
        applyError = error?.message || String(error);
      }
    }
    await rebuildTrayMenu();
    return { theme, applied, applyError };
  });
  ipcMain.handle("studio:apply", async () => {
    const applied = await applySkin();
    await rebuildTrayMenu();
    return applied;
  });
  ipcMain.handle("studio:open-folder", (_event, kind) => shell.openPath(kind === "logs" ? themeService.logsDir : themeService.imagesDir));
}

async function initializeApplication() {
  engineRoot = app.isPackaged ? path.join(process.resourcesPath, "engine") : path.resolve(__dirname, "../../../macos");
  stateRoot = path.join(localAppDataPath(), "CodexDreamSkinStudio");
  statePath = path.join(stateRoot, "state.json");
  themeService = new ThemeService({ engineRoot, stateRoot });
  await themeService.initialize();
  registerIpc();
  const icon = nativeImage.createFromPath(iconPath()).resize({ width: 20, height: 20 });
  tray = new Tray(icon);
  tray.on("click", openEditor);
  tray.on("double-click", openEditor);
  await rebuildTrayMenu();
  if (!process.argv.includes("--hidden")) openEditor();
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", openEditor);
  app.whenReady().then(initializeApplication).catch(async (error) => {
    console.error(error);
    await dialog.showMessageBox({ type: "error", title: "Codex Dream Skin 启动失败", message: error.message || String(error) });
    app.quit();
  });
  app.on("window-all-closed", () => {});
}
