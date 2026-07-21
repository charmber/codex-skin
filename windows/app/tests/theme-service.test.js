const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const AdmZip = require("adm-zip");
const { ThemeService, safeId, validateArchiveEntryName } = require("../src/theme-service");

const engineRoot = path.resolve(__dirname, "../../../macos");

test("safeId creates package-safe identifiers", () => {
  assert.equal(safeId("  My Neon Theme  "), "my-neon-theme");
  assert.equal(safeId("初音未来", "custom"), "custom");
});

test("archive paths stay inside one theme package", () => {
  assert.equal(validateArchiveEntryName("theme.json"), "theme.json");
  assert.equal(validateArchiveEntryName("theme/theme.json"), "theme/theme.json");
  assert.throws(() => validateArchiveEntryName("../theme.json"), /不安全路径/);
  assert.throws(() => validateArchiveEntryName("C:\\theme.json"), /不安全路径/);
  assert.throws(() => validateArchiveEntryName("/theme.json"), /不安全路径/);
});

test("Windows theme state supports save, palette switch, export, and import", async (t) => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "codex-dream-windows-test-"));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  const first = new ThemeService({ engineRoot, stateRoot: path.join(root, "first") });
  await first.initialize();
  const initial = await first.activeThemeView();
  assert.equal(initial.layoutId, "stage");
  assert.ok(initial.imageAsset.path.endsWith("background.png"));

  const saved = await first.saveDraft({
    ...initial,
    name: "Windows 测试主题",
    paletteName: "测试配色",
    imagePath: initial.imageAsset.path,
    userAvatarPath: initial.imageAsset.path,
    assistantAvatarPath: initial.imageAsset.path,
  });
  assert.equal(saved.name, "Windows 测试主题");
  assert.match(saved.id, /^custom-/);
  assert.equal(saved.avatars.user, "avatar-user.png");
  assert.equal(saved.avatars.assistant, "avatar-assistant.png");
  assert.ok(await fs.stat(path.join(first.activeDir, saved.avatars.user)).then((stat) => stat.size > 0));
  assert.ok(await fs.stat(path.join(first.activeDir, saved.avatars.assistant)).then((stat) => stat.size > 0));

  const switched = await first.switchPalette("miku-sakura");
  assert.equal(switched.paletteId, "miku-sakura");
  assert.equal(switched.layoutId, "stage");
  assert.ok(await fs.stat(path.join(first.activeDir, switched.image)).then((stat) => stat.size > 0));

  const archive = path.join(root, "roundtrip.cds-theme.zip");
  const exported = await first.exportPackage(archive);
  assert.equal(exported.output, archive);
  assert.ok(exported.bytes > 0);

  const second = new ThemeService({ engineRoot, stateRoot: path.join(root, "second") });
  await second.initialize();
  const imported = await second.importPackage(archive);
  assert.equal(imported.paletteId, "miku-sakura");
  assert.equal((await second.loadTheme()).name, switched.name);

  const unsafeArchive = path.join(root, "unsafe.cds-theme.zip");
  const unsafeZip = new AdmZip(archive);
  unsafeZip.addFile("theme-script.js", Buffer.from("alert('no')"));
  unsafeZip.writeZip(unsafeArchive);
  await assert.rejects(() => second.importPackage(unsafeArchive), /未引用文件/);

  const nestedArchive = path.join(root, "nested.cds-theme.zip");
  const nestedZip = new AdmZip(archive);
  nestedZip.addFile("nested/", Buffer.alloc(0));
  nestedZip.writeZip(nestedArchive);
  await assert.rejects(() => second.importPackage(nestedArchive), /不支持的目录/);
});

test("shared renderers use a slash-safe home suggestions selector", async () => {
  const files = [
    path.join(engineRoot, "renderer", "layouts", "stage", "renderer-inject.js"),
    path.join(engineRoot, "renderer", "layouts", "qq-classic", "qq-classic-renderer.js"),
    path.join(engineRoot, "scripts", "injector.mjs"),
  ];
  for (const file of files) {
    const source = await fs.readFile(file, "utf8");
    assert.match(source, /\[class~=["']group\/home-suggestions["']\]/, file);
    assert.doesNotMatch(source, /\.group\\\\+\/home-suggestions/, file);
  }
});
