import fs from "node:fs/promises";
import path from "node:path";

const [mode, ...args] = process.argv.slice(2);

function valueFor(name, fallback) {
  const index = args.indexOf(`--${name}`);
  if (index < 0) return fallback;
  if (index + 1 >= args.length) throw new Error(`Missing value for --${name}`);
  return args[index + 1];
}

function hasValue(name) {
  return args.includes(`--${name}`);
}

function singleLine(value, max) {
  return String(value ?? "").replace(/[\r\n]+/g, " ").trim().slice(0, max);
}

function numberInRange(value, name, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < min || number > max) {
    throw new Error(`${name} must be between ${min} and ${max}.`);
  }
  return number;
}

async function readTheme(file, label = "theme") {
  const theme = JSON.parse(await fs.readFile(file, "utf8"));
  if (theme?.schemaVersion !== 1 || typeof theme.image !== "string" || !theme.image) {
    throw new Error(`${label} has an unsupported schema or image field.`);
  }
  return theme;
}

async function atomicWrite(file, value) {
  const temporary = `${file}.${process.pid}.tmp`;
  try {
    await fs.writeFile(temporary, value, { mode: 0o600 });
    await fs.rename(temporary, file);
    await fs.chmod(file, 0o600);
  } finally {
    await fs.rm(temporary, { force: true }).catch(() => {});
  }
}

function normalizedPreferences(theme) {
  const opacity = Number(theme.effects?.taskPanelOpacity);
  const blur = Number(theme.effects?.taskPanelBlur);
  const custom = theme.headerText && typeof theme.headerText === "object" ? theme.headerText : {};
  const customText = (key, fallback, max) => typeof custom[key] === "string"
    ? singleLine(custom[key], max)
    : singleLine(fallback, max);
  return {
    effects: {
      taskPanelOpacity: Number.isFinite(opacity) && opacity >= 0 && opacity <= 1 ? opacity : 0.76,
      taskPanelBlur: Number.isFinite(blur) && blur >= 0 && blur <= 40 ? blur : 14,
    },
    headerText: {
      title: customText("title", theme.name || "Codex Dream Skin", 80),
      subtitle: customText("subtitle", theme.brandSubtitle || "CODEX DREAM SKIN", 80),
      status: customText("status", theme.statusText || "DREAM SKIN ONLINE", 80),
    },
    hasCustomHeader: ["title", "subtitle", "status"].some((key) => typeof custom[key] === "string"),
  };
}

const themeDirValue = valueFor("theme-dir", "");
if (!themeDirValue) throw new Error("Pass --theme-dir <directory>.");
const themeDir = path.resolve(themeDirValue);
const themePath = path.join(themeDir, "theme.json");
const theme = await readTheme(themePath);

if (mode === "show") {
  console.log(JSON.stringify(normalizedPreferences(theme), null, 2));
  process.exit(0);
}

if (mode === "effects") {
  const current = normalizedPreferences(theme).effects;
  const opacityPercent = numberInRange(valueFor("opacity", current.taskPanelOpacity * 100), "opacity", 0, 100);
  const blur = numberInRange(valueFor("blur", current.taskPanelBlur), "blur", 0, 40);
  theme.effects = {
    ...(theme.effects && typeof theme.effects === "object" ? theme.effects : {}),
    taskPanelOpacity: Math.round(opacityPercent) / 100,
    taskPanelBlur: Math.round(blur * 10) / 10,
  };
} else if (mode === "header") {
  if (!hasValue("title") && !hasValue("subtitle") && !hasValue("status")) {
    throw new Error("Pass at least one of --title, --subtitle, or --status.");
  }
  const current = normalizedPreferences(theme).headerText;
  theme.headerText = {
    title: hasValue("title") ? singleLine(valueFor("title", ""), 80) : current.title,
    subtitle: hasValue("subtitle") ? singleLine(valueFor("subtitle", ""), 80) : current.subtitle,
    status: hasValue("status") ? singleLine(valueFor("status", ""), 80) : current.status,
  };
} else if (mode === "inherit") {
  const sourceValue = valueFor("from", "");
  if (!sourceValue) throw new Error("Pass --from <theme.json>.");
  const sourcePath = path.resolve(sourceValue);
  const source = await readTheme(sourcePath, "preference source");
  const preferences = normalizedPreferences(source);
  theme.effects = preferences.effects;
  if (preferences.hasCustomHeader) theme.headerText = preferences.headerText;
} else {
  throw new Error("Usage: update-theme-preferences.mjs show|effects|header|inherit --theme-dir <dir> [options]");
}

await atomicWrite(themePath, `${JSON.stringify(theme, null, 2)}\n`);
console.log(JSON.stringify(normalizedPreferences(theme), null, 2));
