const fs = require("node:fs/promises");
const path = require("node:path");
const os = require("node:os");
const { pathToFileURL } = require("node:url");
const AdmZip = require("adm-zip");

const MAX_ARCHIVE_BYTES = 64 * 1024 * 1024;
const MAX_PACKAGE_BYTES = 32 * 1024 * 1024;
const MAX_ENTRIES = 100;
const MAX_JSON_BYTES = 256 * 1024;
const DOCUMENT_FILES = new Set(["README.md", "LICENSE", "LICENSE.md", "LICENSE.txt"]);
const IMAGE_EXTENSIONS = new Set([".png", ".jpg", ".jpeg", ".webp"]);

function exists(file) {
  return fs.access(file).then(() => true).catch(() => false);
}

function safeId(value, fallback = "theme") {
  const normalized = String(value || fallback)
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^[^a-z0-9]+|[^a-z0-9]+$/g, "")
    .slice(0, 70);
  return normalized || fallback;
}

function validateArchiveEntryName(name) {
  if (!name || name.includes("\\") || name.includes("\0") || path.posix.isAbsolute(name)) {
    throw new Error(`主题包包含不安全路径：${JSON.stringify(name)}`);
  }
  const normalized = path.posix.normalize(name.replace(/\/$/, ""));
  if (!normalized || normalized === "." || normalized === ".." || normalized.startsWith("../")) {
    throw new Error(`主题包包含不安全路径：${name}`);
  }
  return normalized;
}

function assertRegularImage(file, stat, maxBytes, label) {
  if (!stat.isFile() || stat.size < 1 || stat.size > maxBytes || !IMAGE_EXTENSIONS.has(path.extname(file).toLowerCase())) {
    throw new Error(`${label} 必须是有效的 PNG、JPEG 或 WebP，且不超过 ${Math.round(maxBytes / 1024 / 1024)} MB。`);
  }
}

async function atomicWrite(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const temporary = `${file}.${process.pid}.tmp`;
  await fs.writeFile(temporary, value);
  await fs.rename(temporary, file);
}

async function replaceDirectory(source, destination) {
  const previous = `${destination}.previous.${process.pid}`;
  await fs.rm(previous, { recursive: true, force: true });
  if (await exists(destination)) await fs.rename(destination, previous);
  try {
    await fs.rename(source, destination);
    await fs.rm(previous, { recursive: true, force: true });
  } catch (error) {
    if (await exists(previous)) await fs.rename(previous, destination).catch(() => {});
    throw error;
  }
}

class ThemeService {
  constructor({ engineRoot, stateRoot }) {
    this.engineRoot = engineRoot;
    this.stateRoot = stateRoot;
    this.activeDir = path.join(stateRoot, "theme");
    this.themesDir = path.join(stateRoot, "themes");
    this.imagesDir = path.join(stateRoot, "images");
    this.logsDir = path.join(stateRoot, "logs");
    this.defaultThemeDir = path.join(engineRoot, "themes", "builtin-miku-aqua");
    this.contractPromise = null;
  }

  async contract() {
    if (!this.contractPromise) {
      this.contractPromise = import(pathToFileURL(path.join(this.engineRoot, "scripts", "theme-contract.mjs")).href);
    }
    return this.contractPromise;
  }

  async renderer() {
    const contract = await this.contract();
    return contract.loadRendererManifest(this.engineRoot);
  }

  async version() {
    return (await fs.readFile(path.join(this.engineRoot, "VERSION"), "utf8")).trim();
  }

  async initialize() {
    await Promise.all([
      fs.mkdir(this.stateRoot, { recursive: true }),
      fs.mkdir(this.themesDir, { recursive: true }),
      fs.mkdir(this.imagesDir, { recursive: true }),
      fs.mkdir(this.logsDir, { recursive: true }),
    ]);
    if (!(await exists(path.join(this.activeDir, "theme.json")))) {
      await fs.cp(this.defaultThemeDir, this.activeDir, { recursive: true });
    }
    const builtinLibrary = path.join(this.themesDir, "miku-aqua-stage");
    if (!(await exists(path.join(builtinLibrary, "theme.json")))) {
      await fs.cp(this.defaultThemeDir, builtinLibrary, { recursive: true });
    }
    await this.loadTheme(this.activeDir, false);
  }

  async loadTheme(directory = this.activeDir, strict = false) {
    const file = path.join(directory, "theme.json");
    const raw = JSON.parse(await fs.readFile(file, "utf8"));
    const contract = await this.contract();
    const renderer = await this.renderer();
    return contract.normalizeTheme(raw, { source: file, renderer, strict });
  }

  async activeThemeView() {
    const theme = await this.loadTheme();
    const asset = async (name) => {
      if (!name) return null;
      const file = path.join(this.activeDir, name);
      const data = await fs.readFile(file);
      const extension = path.extname(file).toLowerCase();
      const mime = extension === ".jpg" || extension === ".jpeg" ? "image/jpeg" : extension === ".webp" ? "image/webp" : "image/png";
      return { path: file, dataUrl: `data:${mime};base64,${data.toString("base64")}` };
    };
    return {
      ...theme,
      imageAsset: await asset(theme.image),
      userAvatarAsset: await asset(theme.avatars.user),
      assistantAvatarAsset: await asset(theme.avatars.assistant),
    };
  }

  async readChoices(directory, nested = false) {
    const entries = await fs.readdir(directory, { withFileTypes: true }).catch(() => []);
    const choices = [];
    for (const entry of entries) {
      const file = nested
        ? path.join(directory, entry.name, "theme.json")
        : path.join(directory, entry.name);
      if (nested ? !entry.isDirectory() : !entry.isFile() || path.extname(entry.name) !== ".json") continue;
      try {
        const value = JSON.parse(await fs.readFile(file, "utf8"));
        choices.push({ id: nested ? entry.name : value.id || path.basename(entry.name, ".json"), name: value.name || entry.name, layoutId: value.layoutId || null });
      } catch {}
    }
    return choices.sort((a, b) => a.name.localeCompare(b.name, "zh-CN"));
  }

  async choices() {
    const [layouts, palettes, themes, imageEntries] = await Promise.all([
      this.readChoices(path.join(this.engineRoot, "layouts")),
      this.readChoices(path.join(this.engineRoot, "palettes")),
      this.readChoices(this.themesDir, true),
      fs.readdir(this.imagesDir, { withFileTypes: true }).catch(() => []),
    ]);
    const backgrounds = imageEntries
      .filter((entry) => entry.isFile() && IMAGE_EXTENSIONS.has(path.extname(entry.name).toLowerCase()))
      .map((entry) => ({ id: entry.name, name: entry.name }));
    return { layouts, palettes, themes, backgrounds };
  }

  async createManifest(theme, existing = {}) {
    const contract = await this.contract();
    const renderer = await this.renderer();
    const engineVersion = await this.version();
    const manifest = contract.createThemePackageManifest(theme, {
      engineVersion,
      existing: { ...existing, preview: theme.image },
      author: "Codex Dream Skin 用户",
    });
    return contract.validateThemePackageManifest(manifest, {
      theme,
      renderer,
      engineVersion,
      source: "manifest.json",
    });
  }

  async validateTheme(theme, strict = true) {
    const contract = await this.contract();
    const renderer = await this.renderer();
    return contract.normalizeTheme(theme, { source: "theme.json", renderer, strict });
  }

  async prepareThemeDirectory(theme, assets, { saveHistory = false, existingManifest = {} } = {}) {
    const temporary = await fs.mkdtemp(path.join(this.stateRoot, ".theme-writing-"));
    try {
      const copyAsset = async (source, preferred, maxBytes, label) => {
        if (!source) return null;
        const absolute = path.resolve(source);
        const stat = await fs.stat(absolute);
        assertRegularImage(absolute, stat, maxBytes, label);
        const extension = path.extname(absolute).toLowerCase();
        const filename = `${preferred}${extension}`;
        await fs.copyFile(absolute, path.join(temporary, filename));
        return filename;
      };

      theme.image = await copyAsset(assets.imagePath, "background", 16 * 1024 * 1024, "背景图片");
      theme.avatars = {
        user: await copyAsset(assets.userAvatarPath, "avatar-user", 4 * 1024 * 1024, "提问头像"),
        assistant: await copyAsset(assets.assistantAvatarPath, "avatar-assistant", 4 * 1024 * 1024, "回答头像"),
      };
      const normalized = await this.validateTheme(theme, true);
      const manifest = await this.createManifest(normalized, existingManifest);
      await Promise.all([
        fs.writeFile(path.join(temporary, "theme.json"), `${JSON.stringify(normalized, null, 2)}\n`),
        fs.writeFile(path.join(temporary, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`),
      ]);
      await replaceDirectory(temporary, this.activeDir);
      if (saveHistory) {
        const history = path.join(this.themesDir, normalized.id);
        const historyTemporary = await fs.mkdtemp(path.join(this.stateRoot, ".history-writing-"));
        await fs.cp(this.activeDir, historyTemporary, { recursive: true });
        await replaceDirectory(historyTemporary, history);
      }
      return normalized;
    } catch (error) {
      await fs.rm(temporary, { recursive: true, force: true });
      throw error;
    }
  }

  async saveDraft(draft) {
    const now = Date.now();
    const baseId = safeId(draft.name, "custom").slice(0, 48);
    const theme = {
      schemaVersion: 1,
      id: `custom-${baseId}-${now}`.slice(0, 80),
      name: String(draft.name || "我的新主题").trim().slice(0, 80),
      paletteId: safeId(draft.paletteId || "custom"),
      paletteName: String(draft.paletteName || draft.name || "自定义配色").trim().slice(0, 80),
      backgroundName: String(draft.backgroundName || "我的背景").trim().slice(0, 80),
      layoutId: draft.layoutId === "qq-classic" ? "qq-classic" : "stage",
      visualStyle: String(draft.visualStyle || (draft.layoutId === "qq-classic" ? "classic-blue-07" : "portal")).slice(0, 80),
      brandSubtitle: String(draft.brandSubtitle || "").slice(0, 80),
      tagline: String(draft.tagline || "").slice(0, 160),
      projectPrefix: String(draft.projectPrefix || "").slice(0, 80),
      projectLabel: String(draft.projectLabel || "").slice(0, 80),
      statusText: String(draft.statusText || "").slice(0, 80),
      quote: String(draft.quote || "").slice(0, 80),
      image: "background.png",
      effects: draft.effects,
      headerText: draft.headerText,
      layoutComponents: draft.layoutComponents,
      colors: draft.colors,
    };
    return this.prepareThemeDirectory(theme, {
      imagePath: draft.imagePath,
      userAvatarPath: draft.userAvatarPath,
      assistantAvatarPath: draft.assistantAvatarPath,
    }, { saveHistory: true });
  }

  async mutateActive(mutator) {
    const current = await this.loadTheme();
    const existingManifest = await fs.readFile(path.join(this.activeDir, "manifest.json"), "utf8").then(JSON.parse).catch(() => ({}));
    const next = await mutator(structuredClone(current));
    const assets = {
      imagePath: path.join(this.activeDir, current.image),
      userAvatarPath: current.avatars.user ? path.join(this.activeDir, current.avatars.user) : null,
      assistantAvatarPath: current.avatars.assistant ? path.join(this.activeDir, current.avatars.assistant) : null,
    };
    return this.prepareThemeDirectory(next, assets, { existingManifest });
  }

  async switchPalette(id) {
    const palettePath = path.join(this.engineRoot, "palettes", `${safeId(id)}.json`);
    const palette = JSON.parse(await fs.readFile(palettePath, "utf8"));
    return this.mutateActive((theme) => ({
      ...theme,
      id: `palette-${palette.id}-${Date.now()}`,
      name: palette.name,
      paletteId: palette.id,
      paletteName: palette.name,
      layoutId: palette.layoutId,
      visualStyle: palette.visualStyle,
      brandSubtitle: palette.brandSubtitle,
      tagline: palette.tagline,
      projectPrefix: palette.projectPrefix,
      projectLabel: palette.projectLabel,
      statusText: palette.statusText,
      quote: palette.quote,
      colors: palette.colors,
    }));
  }

  async switchLayout(id) {
    const layoutId = id === "qq-classic" ? "qq-classic" : "stage";
    const layout = JSON.parse(await fs.readFile(path.join(this.engineRoot, "layouts", `${layoutId}.json`), "utf8"));
    return this.switchPalette(layout.defaultPaletteId);
  }

  async addBackground(source) {
    const absolute = path.resolve(source);
    const stat = await fs.stat(absolute);
    assertRegularImage(absolute, stat, 16 * 1024 * 1024, "背景图片");
    const filename = `${safeId(path.basename(absolute, path.extname(absolute)), "background")}-${Date.now()}${path.extname(absolute).toLowerCase()}`;
    await fs.copyFile(absolute, path.join(this.imagesDir, filename));
    return this.switchBackground(filename);
  }

  async switchBackground(filename) {
    const safeName = path.basename(filename);
    if (safeName !== filename || !IMAGE_EXTENSIONS.has(path.extname(safeName).toLowerCase())) throw new Error("背景文件名无效。");
    const source = path.join(this.imagesDir, safeName);
    const current = await this.loadTheme();
    const existingManifest = await fs.readFile(path.join(this.activeDir, "manifest.json"), "utf8").then(JSON.parse).catch(() => ({}));
    const next = {
      ...current,
      id: `background-${Date.now()}`,
      backgroundName: path.basename(safeName, path.extname(safeName)).slice(0, 80),
    };
    return this.prepareThemeDirectory(next, {
      imagePath: source,
      userAvatarPath: current.avatars.user ? path.join(this.activeDir, current.avatars.user) : null,
      assistantAvatarPath: current.avatars.assistant ? path.join(this.activeDir, current.avatars.assistant) : null,
    }, { existingManifest });
  }

  async switchHistoricalTheme(id) {
    const safe = safeId(id);
    const source = path.join(this.themesDir, safe);
    const theme = await this.loadTheme(source, true);
    const temporary = await fs.mkdtemp(path.join(this.stateRoot, ".theme-switching-"));
    await fs.cp(source, temporary, { recursive: true });
    await replaceDirectory(temporary, this.activeDir);
    return theme;
  }

  async validatePackageDirectory(directory) {
    const manifestFile = path.join(directory, "manifest.json");
    const themeFile = path.join(directory, "theme.json");
    const [manifestStat, themeStat] = await Promise.all([fs.stat(manifestFile), fs.stat(themeFile)]);
    if (manifestStat.size > MAX_JSON_BYTES || themeStat.size > MAX_JSON_BYTES) throw new Error("主题 JSON 文件过大。");
    const [rawManifest, rawTheme] = await Promise.all([
      fs.readFile(manifestFile, "utf8").then(JSON.parse),
      fs.readFile(themeFile, "utf8").then(JSON.parse),
    ]);
    const theme = await this.validateTheme(rawTheme, true);
    const contract = await this.contract();
    const renderer = await this.renderer();
    const manifest = contract.validateThemePackageManifest(rawManifest, {
      theme,
      renderer,
      engineVersion: await this.version(),
      source: manifestFile,
    });
    const referenced = new Set(["manifest.json", "theme.json", theme.image]);
    if (theme.avatars.user) referenced.add(theme.avatars.user);
    if (theme.avatars.assistant) referenced.add(theme.avatars.assistant);
    if (manifest.preview) referenced.add(manifest.preview);
    const entries = await fs.readdir(directory, { withFileTypes: true });
    let total = 0;
    const lower = new Set();
    for (const entry of entries) {
      if (!entry.isFile()) throw new Error(`主题包只允许根目录文件：${entry.name}`);
      const folded = entry.name.toLowerCase();
      if (lower.has(folded)) throw new Error(`主题包包含大小写冲突文件：${entry.name}`);
      lower.add(folded);
      if (!referenced.has(entry.name) && !DOCUMENT_FILES.has(entry.name)) throw new Error(`主题包包含未引用文件：${entry.name}`);
      total += (await fs.stat(path.join(directory, entry.name))).size;
    }
    if (total > MAX_PACKAGE_BYTES) throw new Error("主题包解压后超过 32 MB。 ");
    const contractLimits = await this.contract();
    for (const [name, max, label] of [
      [theme.image, contractLimits.MAX_THEME_BYTES, "背景图片"],
      [theme.avatars.user, contractLimits.MAX_AVATAR_BYTES, "提问头像"],
      [theme.avatars.assistant, contractLimits.MAX_AVATAR_BYTES, "回答头像"],
      [manifest.preview, contractLimits.MAX_THEME_BYTES, "预览图片"],
    ]) {
      if (!name) continue;
      const stat = await fs.stat(path.join(directory, name));
      assertRegularImage(name, stat, max, label);
    }
    return { manifest, theme, referenced };
  }

  async importPackage(archive) {
    const archiveStat = await fs.stat(archive);
    if (!archiveStat.isFile() || archiveStat.size < 1 || archiveStat.size > MAX_ARCHIVE_BYTES) throw new Error("主题 ZIP 必须小于 64 MB。");
    const zip = new AdmZip(archive);
    const entries = zip.getEntries();
    if (!entries.length || entries.length > MAX_ENTRIES) throw new Error("主题 ZIP 文件数量无效。");
    let total = 0;
    const normalized = entries.map((entry) => {
      const name = validateArchiveEntryName(entry.entryName);
      const unixMode = (entry.header.attr >>> 16) & 0xffff;
      if ((unixMode & 0o170000) === 0o120000) throw new Error("主题 ZIP 不允许符号链接。");
      total += Number(entry.header.size || 0);
      return { entry, name };
    });
    if (total > MAX_PACKAGE_BYTES) throw new Error("主题 ZIP 声明的解压体积超过 32 MB。");
    const files = normalized.filter(({ entry }) => !entry.isDirectory);
    const prefixes = files.map(({ name }) => name.includes("/") ? name.split("/")[0] : null);
    const prefix = prefixes.every(Boolean) && new Set(prefixes).size === 1 ? `${prefixes[0]}/` : "";
    for (const { entry, name } of normalized.filter(({ entry }) => entry.isDirectory)) {
      const allowedWrapper = prefix && name === prefix.slice(0, -1);
      if (!allowedWrapper) throw new Error(`主题 ZIP 包含不支持的目录：${entry.entryName}`);
    }
    const temporary = await fs.mkdtemp(path.join(os.tmpdir(), "codex-dream-theme-import-"));
    try {
      const entryNames = new Set();
      for (const { entry, name } of files) {
        const relative = prefix && name.startsWith(prefix) ? name.slice(prefix.length) : name;
        if (!relative || relative.includes("/")) throw new Error("主题 ZIP 只能在根目录或单一顶层文件夹内放置文件。");
        const folded = relative.toLowerCase();
        if (entryNames.has(folded)) throw new Error(`主题 ZIP 包含重复或大小写冲突文件：${relative}`);
        entryNames.add(folded);
        await fs.writeFile(path.join(temporary, relative), entry.getData());
      }
      const validated = await this.validatePackageDirectory(temporary);
      const libraryTemporary = await fs.mkdtemp(path.join(this.stateRoot, ".theme-importing-"));
      await fs.cp(temporary, libraryTemporary, { recursive: true });
      await replaceDirectory(libraryTemporary, path.join(this.themesDir, validated.manifest.id));
      const activeTemporary = await fs.mkdtemp(path.join(this.stateRoot, ".theme-activating-"));
      await fs.cp(temporary, activeTemporary, { recursive: true });
      await replaceDirectory(activeTemporary, this.activeDir);
      return validated.theme;
    } finally {
      await fs.rm(temporary, { recursive: true, force: true });
    }
  }

  async exportPackage(output) {
    const theme = await this.loadTheme();
    const existing = await fs.readFile(path.join(this.activeDir, "manifest.json"), "utf8").then(JSON.parse).catch(() => ({}));
    const manifest = await this.createManifest(theme, existing);
    const zip = new AdmZip();
    zip.addFile("manifest.json", Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`));
    zip.addFile("theme.json", Buffer.from(`${JSON.stringify(theme, null, 2)}\n`));
    const files = new Set([theme.image, theme.avatars.user, theme.avatars.assistant, manifest.preview].filter(Boolean));
    for (const name of files) zip.addLocalFile(path.join(this.activeDir, name), "", name);
    await fs.mkdir(path.dirname(output), { recursive: true });
    zip.writeZip(output);
    const stat = await fs.stat(output);
    if (stat.size < 1 || stat.size > MAX_ARCHIVE_BYTES) throw new Error("导出的主题 ZIP 大小无效。");
    return { output, bytes: stat.size, name: theme.name };
  }
}

module.exports = { ThemeService, safeId, validateArchiveEntryName };
