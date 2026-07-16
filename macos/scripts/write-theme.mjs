import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const [mode, ...args] = process.argv.slice(2);

function valueFor(name, fallback = "") {
  const index = args.indexOf(`--${name}`);
  if (index < 0) return fallback;
  const value = args[index + 1];
  if (!value || value.startsWith("--")) throw new Error(`Missing value for --${name}`);
  return value;
}

function hasValue(name) {
  return args.includes(`--${name}`);
}

function validateHex(value, name) {
  if (!/^#[0-9a-f]{6}$/i.test(value)) throw new Error(`${name} must be a six-digit hex color.`);
  return value.toLowerCase();
}

function validateColor(value, name) {
  const normalized = String(value ?? "").trim();
  if (/^#[0-9a-f]{6}$/i.test(normalized) || /^rgba?\([0-9., %]+\)$/i.test(normalized)) {
    return normalized;
  }
  throw new Error(`${name} must be a six-digit hex or rgb/rgba color.`);
}

function hexToRgba(hex, alpha) {
  const value = Number.parseInt(hex.slice(1), 16);
  return `rgba(${value >> 16}, ${(value >> 8) & 255}, ${value & 255}, ${alpha})`;
}

async function atomicWrite(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
  const temporary = `${file}.${process.pid}.tmp`;
  try {
    await fs.writeFile(temporary, value, { mode: 0o600 });
    await fs.rename(temporary, file);
    await fs.chmod(file, 0o600);
  } finally {
    await fs.rm(temporary, { force: true }).catch(() => {});
  }
}

async function readJson(file, label) {
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch (error) {
    throw new Error(`Could not read ${label} ${file}: ${error.message}`);
  }
}

function text(value, fallback, max) {
  return typeof value === "string" && value.trim() ? value.trim().slice(0, max) : fallback;
}

function normalizePalette(raw, source) {
  if (raw?.schemaVersion !== 1) throw new Error(`${source} has an unsupported palette schema.`);
  const requiredColors = [
    "background", "panel", "panelAlt", "accent", "accentAlt", "secondary",
    "highlight", "text", "muted", "line",
  ];
  const colors = {};
  for (const key of requiredColors) colors[key] = validateColor(raw.colors?.[key], `colors.${key}`);
  return {
    id: text(raw.id, "custom-palette", 80),
    name: text(raw.name, "自定义配色", 80),
    visualStyle: text(raw.visualStyle, "miku-07", 80),
    brandSubtitle: text(raw.brandSubtitle, "MIKU CODEX", 80),
    tagline: text(raw.tagline, "和初音未来一起，把灵感写成可以运行的代码。", 160),
    projectPrefix: text(raw.projectPrefix, "选择舞台 · ", 80),
    projectLabel: text(raw.projectLabel, "♪  选择项目", 80),
    statusText: text(raw.statusText, "MIKU STAGE ONLINE", 80),
    quote: text(raw.quote, "BE TOGETHER, BE FUTURE", 80),
    colors,
  };
}

const outputDir = path.resolve(valueFor("output-dir", path.join(root, "assets")));
const themePath = path.join(outputDir, "theme.json");

if (mode === "reset-demo") {
  if (outputDir === path.join(root, "assets")) {
    throw new Error("Refusing to delete the bundled demo assets; pass a user --output-dir.");
  }
  await fs.rm(outputDir, { recursive: true, force: true });
  console.log("Restored the bundled abstract demo preset.");
  process.exit(0);
}

if (mode === "apply-palette") {
  const palettePath = path.resolve(valueFor("palette"));
  const current = await readJson(themePath, "active theme");
  if (current.schemaVersion !== 1 || typeof current.image !== "string" || !current.image) {
    throw new Error(`${themePath} has an unsupported schema or image field.`);
  }
  const palette = normalizePalette(await readJson(palettePath, "palette"), palettePath);
  const next = {
    ...current,
    id: `palette-${palette.id}-${Date.now()}`,
    name: palette.name,
    paletteId: palette.id,
    paletteName: palette.name,
    visualStyle: palette.visualStyle,
    brandSubtitle: palette.brandSubtitle,
    tagline: palette.tagline,
    projectPrefix: palette.projectPrefix,
    projectLabel: palette.projectLabel,
    statusText: palette.statusText,
    quote: palette.quote,
    colors: palette.colors,
  };
  await atomicWrite(themePath, `${JSON.stringify(next, null, 2)}\n`);
  console.log(`Applied palette “${palette.name}” and kept background “${next.backgroundName || next.image}”.`);
  process.exit(0);
}

if (mode !== "custom") {
  throw new Error("Usage: write-theme.mjs custom [options] | apply-palette --palette <file> | reset-demo --output-dir <dir>");
}

const inheritPath = valueFor("inherit-theme", "");
const inherited = inheritPath ? await readJson(path.resolve(inheritPath), "inherited theme") : {};

const image = path.basename(valueFor("image", "background.jpg"));
if (!/\.(?:png|jpe?g|webp)$/i.test(image)) throw new Error("image must be a PNG, JPEG, or WebP filename.");
const imagePath = path.join(outputDir, image);
const imageStat = await fs.stat(imagePath);
if (!imageStat.isFile() || imageStat.size < 1 || imageStat.size > 16 * 1024 * 1024) {
  throw new Error("The prepared theme image must be non-empty and no larger than 16 MB.");
}

const backgroundName = text(valueFor("background-name", valueFor("name", "")), "我的背景", 80);
const inheritedColors = inherited.colors && typeof inherited.colors === "object" ? inherited.colors : {};
const accent = validateHex(valueFor("accent", inheritedColors.accent || "#7cff46"), "accent");
const secondary = validateHex(valueFor("secondary", inheritedColors.secondary || "#36d7e8"), "secondary");
const highlight = validateHex(valueFor("highlight", inheritedColors.highlight || "#642a8c"), "highlight");
const accentAlt = hasValue("accent") ? accent : validateColor(inheritedColors.accentAlt || accent, "accentAlt");
const paletteName = text(inherited.paletteName, "", 80);
const name = paletteName || text(valueFor("name", inherited.name || "我的 Codex Dream Skin"), "我的 Codex Dream Skin", 80);
const tagline = text(valueFor("tagline", inherited.tagline || "把喜欢的画面变成可交互的 Codex 工作台。"), "把喜欢的画面变成可交互的 Codex 工作台。", 160);
const quote = text(valueFor("quote", inherited.quote || "MAKE SOMETHING WONDERFUL"), "MAKE SOMETHING WONDERFUL", 80);

const custom = {
  schemaVersion: 1,
  id: `custom-${Date.now()}`,
  name,
  paletteId: text(inherited.paletteId, "custom", 80),
  paletteName: paletteName || name,
  backgroundName,
  visualStyle: text(inherited.visualStyle, "portal", 80),
  brandSubtitle: text(inherited.brandSubtitle, "CODEX DREAM SKIN", 80),
  tagline,
  projectPrefix: text(inherited.projectPrefix, "选择项目 · ", 80),
  projectLabel: text(inherited.projectLabel, "◉  选择项目", 80),
  statusText: text(inherited.statusText, "DREAM SKIN ONLINE", 80),
  quote,
  image,
  effects: inherited.effects && typeof inherited.effects === "object" ? inherited.effects : undefined,
  headerText: inherited.headerText && typeof inherited.headerText === "object" ? inherited.headerText : undefined,
  colors: {
    background: validateColor(inheritedColors.background || "#071116", "background"),
    panel: validateColor(inheritedColors.panel || "#0b1a20", "panel"),
    panelAlt: validateColor(inheritedColors.panelAlt || "#10272c", "panelAlt"),
    accent,
    accentAlt,
    secondary,
    highlight,
    text: validateColor(inheritedColors.text || "#f2fff7", "text"),
    muted: validateColor(inheritedColors.muted || "#a7c2ba", "muted"),
    line: hasValue("accent") ? hexToRgba(accent, 0.32) : validateColor(inheritedColors.line || hexToRgba(accent, 0.32), "line"),
  },
};

await atomicWrite(themePath, `${JSON.stringify(custom, null, 2)}\n`);
console.log(`Saved custom theme “${custom.name}”.`);
