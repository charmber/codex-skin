const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const test = require("node:test");

test("release metadata stays aligned", async () => {
  const appRoot = path.resolve(__dirname, "..");
  const windowsRoot = path.resolve(appRoot, "..");
  const packageJson = JSON.parse(await fs.readFile(path.join(appRoot, "package.json"), "utf8"));
  const windowsVersion = (await fs.readFile(path.join(windowsRoot, "VERSION"), "utf8")).trim();
  const macVersion = (await fs.readFile(path.resolve(windowsRoot, "../macos/VERSION"), "utf8")).trim();
  assert.equal(packageJson.version, windowsVersion);
  assert.equal(windowsVersion, macVersion);
  assert.match(packageJson.build.artifactName, /Windows/);
});

test("Windows classic renderer keeps native header controls un-cloned", async () => {
  const appRoot = path.resolve(__dirname, "..");
  const rendererRoot = path.resolve(appRoot, "../../macos/renderer/layouts/qq-classic");
  const [rendererSource, stylesheet] = await Promise.all([
    fs.readFile(path.join(rendererRoot, "qq-classic-renderer.js"), "utf8"),
    fs.readFile(path.join(rendererRoot, "qq-classic.css"), "utf8"),
  ]);
  assert.match(rendererSource, /const PLATFORM_ATTR = "data-dream-platform";/);
  assert.match(rendererSource, /runtimePlatform === "windows"/);
  assert.match(stylesheet, /data-dream-platform="windows"\] \.dream-retro-native-controls/);
  assert.match(stylesheet, /data-dream-platform="windows"\] \.dream-retro-titlebar[\s\S]*?-webkit-app-region: drag;/);
  assert.match(stylesheet, /data-dream-platform="windows"\] \.dream-retro-toolbar[\s\S]*?-webkit-app-region: no-drag;/);
  assert.match(stylesheet, /data-dream-platform="windows"\]\[data-dream-task-route="true"\][\s\S]*?aside\.app-shell-left-panel > \.max-w-full\.overflow-hidden[\s\S]*?top: 0 !important;/);
  assert.match(rendererSource, /const ensureRetroProfile = \(enabled = true\)/);
  assert.match(rendererSource, /ensureRetroProfile\(!settingsRoute\)/);
  assert.match(stylesheet, /data-dream-platform="windows"\]:is\([\s\S]*?input\[placeholder\*="settings" i\][\s\S]*?main\.main-surface > div:first-of-type[\s\S]*?top: 0 !important;/);
  assert.doesNotMatch(stylesheet, /\.app-shell-left-panel > :first-child:not\(nav\)\s*\{\s*display: none !important;/);
});

test("Windows theme studio exposes an independent conversation text color", async () => {
  const appRoot = path.resolve(__dirname, "..");
  const engineRoot = path.resolve(appRoot, "../../macos");
  const [studioSource, contractSource, stageSource, classicSource] = await Promise.all([
    fs.readFile(path.join(appRoot, "src/renderer/theme-studio.js"), "utf8"),
    fs.readFile(path.join(engineRoot, "scripts/theme-contract.mjs"), "utf8"),
    fs.readFile(path.join(engineRoot, "renderer/layouts/stage/dream-skin.css"), "utf8"),
    fs.readFile(path.join(engineRoot, "renderer/layouts/qq-classic/qq-classic.css"), "utf8"),
  ]);
  assert.match(studioSource, /\["conversationText", "聊天记录文字"\]/);
  assert.match(contractSource, /"highlight", "text", "conversationText", "muted", "line"/);
  for (const source of [stageSource, classicSource]) {
    assert.match(source, /\[data-content-search-unit-key\$=":assistant"\]/);
    assert.match(source, /\[data-message-author-role="user"\]/);
    assert.match(source, /color: var\(--ds-conversation-text\) !important;/);
  }
});
