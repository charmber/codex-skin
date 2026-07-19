import fs from "node:fs/promises";
import path from "node:path";

export const THEME_PACKAGE_FORMAT = "codex-dream-skin-theme";
export const THEME_PACKAGE_FORMAT_VERSION = 1;
export const RENDERER_API_VERSION = 1;
export const MAX_THEME_BYTES = 16 * 1024 * 1024;
export const MAX_AVATAR_BYTES = 4 * 1024 * 1024;

const COLOR_KEYS = [
  "background", "panel", "panelAlt", "accent", "accentAlt", "secondary",
  "highlight", "text", "muted", "line",
];

const DEFAULT_COLORS = {
  background: "#071116",
  panel: "#0b1a20",
  panelAlt: "#10272c",
  accent: "#7cff46",
  accentAlt: "#b8ff3d",
  secondary: "#36d7e8",
  highlight: "#642a8c",
  text: "#e9fff1",
  muted: "#9ebdb3",
  line: "rgba(124, 255, 70, .28)",
};

function rejectUnknownKeys(value, allowed, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  const unknown = Object.keys(value).filter((key) => !allowed.has(key));
  if (unknown.length) throw new Error(`${label} contains unsupported field: ${unknown[0]}`);
}

function requireTextField(value, label) {
  if (typeof value !== "string" || !value.trim()) throw new Error(`${label} is required.`);
}

function text(value, fallback, max) {
  return typeof value === "string" && value.trim()
    ? value.replace(/[\r\n]+/g, " ").trim().slice(0, max)
    : fallback;
}

function optionalText(value, max) {
  return typeof value === "string"
    ? value.replace(/[\r\n]+/g, " ").trim().slice(0, max)
    : null;
}

function number(value, fallback, min, max, label, strict) {
  const parsed = Number(value);
  if (Number.isFinite(parsed) && parsed >= min && parsed <= max) return parsed;
  if (strict) throw new Error(`${label} must be between ${min} and ${max}.`);
  return fallback;
}

function color(value, fallback, label, strict) {
  if (typeof value === "string") {
    const normalized = value.trim();
    if (/^#[0-9a-f]{6}$/i.test(normalized) || /^rgba?\([0-9., %]+\)$/i.test(normalized)) {
      return normalized;
    }
  }
  if (strict) throw new Error(`${label} must be a six-digit hex or rgb/rgba color.`);
  return fallback;
}

export function safeAssetName(value, label, { optional = false } = {}) {
  if ((value === null || value === undefined || value === "") && optional) return null;
  if (typeof value !== "string" || !value || path.basename(value) !== value) {
    throw new Error(`${label} must be a filename in the theme package root.`);
  }
  const extension = path.extname(value).toLowerCase();
  if (![".png", ".jpg", ".jpeg", ".webp"].includes(extension)) {
    throw new Error(`${label} must use PNG, JPEG, or WebP.`);
  }
  return value;
}

function safeRendererPath(rendererRoot, value, label) {
  if (typeof value !== "string" || !value || path.isAbsolute(value)) {
    throw new Error(`${label} must be a relative renderer path.`);
  }
  const resolved = path.resolve(rendererRoot, value);
  const relative = path.relative(rendererRoot, resolved);
  if (!relative || relative.startsWith("..") || path.isAbsolute(relative)) {
    throw new Error(`${label} escapes the renderer directory.`);
  }
  return resolved;
}

export async function loadRendererManifest(engineRoot) {
  const rendererRoot = path.join(engineRoot, "renderer");
  const manifestPath = path.join(rendererRoot, "manifest.json");
  const raw = JSON.parse(await fs.readFile(manifestPath, "utf8"));
  if (raw.schemaVersion !== 1 || raw.apiVersion !== RENDERER_API_VERSION || !raw.layouts) {
    throw new Error(`${manifestPath} has an unsupported renderer contract.`);
  }

  const layouts = {};
  for (const [id, value] of Object.entries(raw.layouts)) {
    if (!/^[a-z0-9][a-z0-9._-]{0,63}$/.test(id) || !value || typeof value !== "object") {
      throw new Error(`Invalid renderer layout id: ${id}`);
    }
    const assets = {};
    for (const [assetId, assetPath] of Object.entries(value.assets ?? {})) {
      assets[assetId] = safeRendererPath(rendererRoot, assetPath, `layouts.${id}.assets.${assetId}`);
    }
    layouts[id] = {
      id,
      name: text(value.name, id, 80),
      kind: text(value.kind, id, 40),
      stylesheet: safeRendererPath(rendererRoot, value.stylesheet, `layouts.${id}.stylesheet`),
      script: safeRendererPath(rendererRoot, value.script, `layouts.${id}.script`),
      assets,
    };
  }
  if (!layouts.stage) throw new Error("Renderer contract must provide the stage layout.");
  return {
    root: rendererRoot,
    manifestPath,
    schemaVersion: raw.schemaVersion,
    apiVersion: raw.apiVersion,
    id: text(raw.id, "codex-dream-skin-renderer", 80),
    name: text(raw.name, "Codex Dream Skin Renderer", 80),
    layouts,
  };
}

export function normalizeTheme(raw, { source = "theme.json", renderer, strict = false } = {}) {
  if (!raw || raw.schemaVersion !== 1 || typeof raw.image !== "string" || !raw.image) {
    throw new Error(`${source} has an unsupported schema or image field.`);
  }
  if (strict) {
    rejectUnknownKeys(raw, new Set([
      "schemaVersion", "id", "name", "paletteId", "paletteName", "backgroundName",
      "layoutId", "visualStyle", "layoutComponents", "brandSubtitle", "tagline",
      "projectPrefix", "projectLabel", "statusText", "quote", "image", "avatars",
      "effects", "headerText", "colors",
    ]), "theme");
    rejectUnknownKeys(raw.colors, new Set(COLOR_KEYS), "theme.colors");
    rejectUnknownKeys(raw.effects, new Set(["taskPanelOpacity", "taskPanelBlur"]), "theme.effects");
    if (raw.avatars !== undefined) {
      rejectUnknownKeys(raw.avatars, new Set(["user", "assistant"]), "theme.avatars");
    }
    if (raw.headerText !== undefined) {
      rejectUnknownKeys(raw.headerText, new Set(["title", "subtitle", "status"]), "theme.headerText");
      for (const field of ["title", "subtitle", "status"]) {
        if (raw.headerText[field] !== undefined && raw.headerText[field] !== null && typeof raw.headerText[field] !== "string") {
          throw new Error(`theme.headerText.${field} must be a string or null.`);
        }
      }
    }
    if (raw.layoutComponents !== undefined) {
      rejectUnknownKeys(raw.layoutComponents, new Set([
        "retroHeader", "toolbar", "threePane", "autoOpenSummary", "companion",
        "profileCard", "homePet", "minWidth", "rightWidth", "windowTitle",
        "profileName", "profileStatus", "companionTitle", "companionStatus",
      ]), "theme.layoutComponents");
      for (const field of [
        "retroHeader", "toolbar", "threePane", "autoOpenSummary", "companion", "profileCard", "homePet",
      ]) {
        if (raw.layoutComponents[field] !== undefined && typeof raw.layoutComponents[field] !== "boolean") {
          throw new Error(`theme.layoutComponents.${field} must be true or false.`);
        }
      }
      for (const field of ["windowTitle", "profileName", "profileStatus", "companionTitle", "companionStatus"]) {
        if (raw.layoutComponents[field] !== undefined && typeof raw.layoutComponents[field] !== "string") {
          throw new Error(`theme.layoutComponents.${field} must be a string.`);
        }
      }
    }
    for (const field of [
      "brandSubtitle", "tagline", "projectPrefix", "projectLabel", "statusText", "quote",
    ]) {
      if (raw[field] !== undefined && typeof raw[field] !== "string") {
        throw new Error(`theme.${field} must be a string.`);
      }
    }
    for (const field of ["id", "name", "paletteId", "paletteName", "backgroundName", "layoutId", "visualStyle"]) {
      requireTextField(raw[field], `theme.${field}`);
    }
  }
  const image = safeAssetName(raw.image, "theme.image");
  const visualStyle = text(raw.visualStyle, "portal", 80);
  const inferredLayout = visualStyle === "classic-blue-07" ? "qq-classic" : "stage";
  const layoutId = text(raw.layoutId, inferredLayout, 64);
  if (strict && (typeof raw.layoutId !== "string" || !raw.layoutId.trim())) {
    throw new Error("theme.layoutId is required in a portable theme package.");
  }
  if (!renderer?.layouts?.[layoutId]) {
    throw new Error(`Theme requires unsupported renderer layout: ${layoutId}`);
  }

  const colors = {};
  for (const key of COLOR_KEYS) {
    colors[key] = color(raw.colors?.[key], DEFAULT_COLORS[key], `theme.colors.${key}`, strict);
  }
  const themeId = text(raw.id, strict ? "" : "custom", 80);
  const name = text(raw.name, strict ? "" : "Codex Dream Skin", 80);
  if (strict && !/^[a-z0-9][a-z0-9._-]{0,79}$/.test(themeId)) {
    throw new Error("theme.id must use 1-80 lowercase letters, digits, dots, underscores, or hyphens.");
  }
  if (strict && !name) throw new Error("theme.name is required.");

  return {
    schemaVersion: 1,
    id: themeId,
    name,
    visualStyle,
    layoutId,
    paletteId: text(raw.paletteId, "custom", 80),
    paletteName: text(raw.paletteName, raw.name || "自定义配色", 80),
    backgroundName: text(raw.backgroundName, image, 80),
    brandSubtitle: optionalText(raw.brandSubtitle, 80) ?? "CODEX DREAM SKIN",
    tagline: optionalText(raw.tagline, 160) ?? "Make something wonderful.",
    projectPrefix: optionalText(raw.projectPrefix, 80) ?? "选择项目 · ",
    projectLabel: optionalText(raw.projectLabel, 80) ?? "◉  选择项目",
    statusText: optionalText(raw.statusText, 80) ?? "DREAM SKIN ONLINE",
    quote: optionalText(raw.quote, 80) ?? "MAKE SOMETHING WONDERFUL",
    image,
    avatars: {
      user: safeAssetName(raw.avatars?.user, "theme.avatars.user", { optional: true }),
      assistant: safeAssetName(raw.avatars?.assistant, "theme.avatars.assistant", { optional: true }),
    },
    effects: {
      taskPanelOpacity: number(raw.effects?.taskPanelOpacity, 0.76, 0, 1, "theme.effects.taskPanelOpacity", strict),
      taskPanelBlur: number(raw.effects?.taskPanelBlur, 14, 0, 40, "theme.effects.taskPanelBlur", strict),
    },
    headerText: {
      title: optionalText(raw.headerText?.title, 80),
      subtitle: optionalText(raw.headerText?.subtitle, 80),
      status: optionalText(raw.headerText?.status, 80),
    },
    layoutComponents: {
      retroHeader: raw.layoutComponents?.retroHeader !== false,
      toolbar: raw.layoutComponents?.toolbar !== false,
      threePane: raw.layoutComponents?.threePane !== false,
      autoOpenSummary: raw.layoutComponents?.autoOpenSummary !== false,
      companion: raw.layoutComponents?.companion !== false,
      profileCard: raw.layoutComponents?.profileCard !== false,
      homePet: raw.layoutComponents?.homePet !== false,
      minWidth: number(
        raw.layoutComponents?.minWidth,
        1180,
        1080,
        2400,
        "theme.layoutComponents.minWidth",
        strict && raw.layoutComponents?.minWidth !== undefined,
      ),
      rightWidth: number(
        raw.layoutComponents?.rightWidth,
        300,
        272,
        420,
        "theme.layoutComponents.rightWidth",
        strict && raw.layoutComponents?.rightWidth !== undefined,
      ),
      windowTitle: optionalText(raw.layoutComponents?.windowTitle, 60) ?? "Codex 2007",
      profileName: optionalText(raw.layoutComponents?.profileName, 48) ?? "",
      profileStatus: optionalText(raw.layoutComponents?.profileStatus, 32) ?? "在线",
      companionTitle: optionalText(raw.layoutComponents?.companionTitle, 48) ?? "Codex 伙伴",
      companionStatus: optionalText(raw.layoutComponents?.companionStatus, 64) ?? "在线 · 随时待命",
    },
    colors,
  };
}

export function compareVersions(lhs, rhs) {
  const parts = (value) => String(value).split(/[.-]/).slice(0, 3).map((part) => Number(part) || 0);
  const left = parts(lhs);
  const right = parts(rhs);
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] < right[index] ? -1 : 1;
  }
  return 0;
}

export function validateThemePackageManifest(raw, { theme, renderer, engineVersion, source = "manifest.json" }) {
  if (!raw || raw.format !== THEME_PACKAGE_FORMAT || raw.formatVersion !== THEME_PACKAGE_FORMAT_VERSION) {
    throw new Error(`${source} is not a supported Codex Dream Skin theme package.`);
  }
  rejectUnknownKeys(raw, new Set([
    "format", "formatVersion", "id", "name", "version", "author", "description",
    "license", "homepage", "renderer", "theme", "preview",
  ]), "manifest");
  rejectUnknownKeys(raw.renderer, new Set(["apiVersion", "minEngineVersion", "layoutId"]), "manifest.renderer");
  for (const field of ["author", "description", "license", "homepage"]) {
    if (raw[field] !== undefined && typeof raw[field] !== "string") {
      throw new Error(`manifest.${field} must be a string.`);
    }
  }
  const id = text(raw.id, "", 80);
  const name = text(raw.name, "", 80);
  const version = text(raw.version, "", 40);
  if (!/^[a-z0-9][a-z0-9._-]{0,79}$/.test(id)) throw new Error("manifest.id has an invalid package id.");
  if (!name) throw new Error("manifest.name is required.");
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error("manifest.version must use semantic versioning such as 1.0.0.");
  }
  if (raw.theme !== "theme.json") throw new Error("manifest.theme must be theme.json.");
  if (id !== theme.id) throw new Error("manifest.id must match theme.id.");
  const apiVersion = Number(raw.renderer?.apiVersion);
  const layoutId = text(raw.renderer?.layoutId, "", 64);
  const minEngineVersion = text(raw.renderer?.minEngineVersion, "", 40);
  if (apiVersion !== renderer.apiVersion) {
    throw new Error(`Theme renderer API ${apiVersion || "missing"} is incompatible with API ${renderer.apiVersion}.`);
  }
  if (layoutId !== theme.layoutId || !renderer.layouts[layoutId]) {
    throw new Error("manifest.renderer.layoutId must match a supported theme.layoutId.");
  }
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(minEngineVersion)) {
    throw new Error("manifest.renderer.minEngineVersion must use semantic versioning.");
  }
  if (compareVersions(engineVersion, minEngineVersion) < 0) {
    throw new Error(`Theme requires Codex Dream Skin ${minEngineVersion} or newer; installed version is ${engineVersion}.`);
  }
  const preview = raw.preview === undefined || raw.preview === null || raw.preview === ""
    ? null
    : safeAssetName(raw.preview, "manifest.preview");
  const author = optionalText(raw.author, 120);
  const description = optionalText(raw.description, 240);
  const license = optionalText(raw.license, 80);
  const homepage = optionalText(raw.homepage, 300);
  return {
    format: THEME_PACKAGE_FORMAT,
    formatVersion: THEME_PACKAGE_FORMAT_VERSION,
    id,
    name,
    version,
    ...(author ? { author } : {}),
    ...(description ? { description } : {}),
    ...(license ? { license } : {}),
    ...(homepage ? { homepage } : {}),
    renderer: { apiVersion, minEngineVersion, layoutId },
    theme: "theme.json",
    ...(preview ? { preview } : {}),
  };
}

export function createThemePackageManifest(theme, { engineVersion, existing = {}, author = null } = {}) {
  return {
    format: THEME_PACKAGE_FORMAT,
    formatVersion: THEME_PACKAGE_FORMAT_VERSION,
    id: theme.id,
    name: theme.name,
    version: typeof existing.version === "string" && /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(existing.version)
      ? existing.version : "1.0.0",
    ...(optionalText(existing.author, 120) || optionalText(author, 120)
      ? { author: optionalText(existing.author, 120) || optionalText(author, 120) } : {}),
    ...(optionalText(existing.description, 240) ? { description: optionalText(existing.description, 240) } : {}),
    ...(optionalText(existing.license, 80) ? { license: optionalText(existing.license, 80) } : {}),
    ...(optionalText(existing.homepage, 300) ? { homepage: optionalText(existing.homepage, 300) } : {}),
    renderer: {
      apiVersion: RENDERER_API_VERSION,
      minEngineVersion: engineVersion,
      layoutId: theme.layoutId,
    },
    theme: "theme.json",
    preview: theme.image,
  };
}
