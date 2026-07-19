import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  MAX_AVATAR_BYTES,
  MAX_THEME_BYTES,
  createThemePackageManifest,
  loadRendererManifest,
  normalizeTheme,
  validateThemePackageManifest,
} from "./theme-contract.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const engineVersion = (await fs.readFile(path.join(root, "VERSION"), "utf8")).trim();
const renderer = await loadRendererManifest(root);
const defaultThemeRoot = path.join(root, "themes", "builtin-miku-aqua");
const defaultStateRoot = path.join(os.homedir(), "Library", "Application Support", "CodexDreamSkinStudio");
const MAX_ARCHIVE_BYTES = 64 * 1024 * 1024;
const MAX_PACKAGE_BYTES = 32 * 1024 * 1024;
const MAX_ENTRIES = 100;
const MAX_JSON_BYTES = 256 * 1024;
const DOCUMENT_FILES = new Set(["README.md", "LICENSE", "LICENSE.md", "LICENSE.txt"]);

const [mode, ...args] = process.argv.slice(2);

function valueFor(name, fallback = "") {
  const index = args.indexOf(`--${name}`);
  if (index < 0) return fallback;
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) throw new Error(`Missing value for --${name}`);
  return value;
}

function hasFlag(name) {
  return args.includes(`--${name}`);
}

async function readJson(file, label) {
  const stat = await fs.stat(file);
  if (!stat.isFile() || stat.size < 2 || stat.size > MAX_JSON_BYTES) {
    throw new Error(`${label} must be a non-empty JSON file no larger than ${MAX_JSON_BYTES} bytes.`);
  }
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch (error) {
    throw new Error(`${label} is not valid JSON: ${error.message}`);
  }
}

async function optionalJson(file) {
  try {
    return await readJson(file, path.basename(file));
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

async function assetStat(directory, filename, maxBytes, label) {
  const file = path.join(directory, filename);
  const stat = await fs.lstat(file);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size < 1 || stat.size > maxBytes) {
    throw new Error(`${label} must be a non-empty regular file no larger than ${maxBytes} bytes.`);
  }
  return { file, stat };
}

function isMetadataName(name) {
  return name === ".DS_Store" || name.startsWith("._");
}

async function validatePackageDirectory(directory) {
  const packageRoot = path.resolve(directory);
  const [rawManifest, rawTheme] = await Promise.all([
    readJson(path.join(packageRoot, "manifest.json"), "manifest.json"),
    readJson(path.join(packageRoot, "theme.json"), "theme.json"),
  ]);
  const theme = normalizeTheme(rawTheme, {
    source: path.join(packageRoot, "theme.json"),
    renderer,
    strict: true,
  });
  const manifest = validateThemePackageManifest(rawManifest, {
    theme,
    renderer,
    engineVersion,
    source: path.join(packageRoot, "manifest.json"),
  });

  const referenced = new Set(["manifest.json", "theme.json", theme.image]);
  if (theme.avatars.user) referenced.add(theme.avatars.user);
  if (theme.avatars.assistant) referenced.add(theme.avatars.assistant);
  if (manifest.preview) referenced.add(manifest.preview);
  const names = await fs.readdir(packageRoot);
  if (names.length > MAX_ENTRIES) throw new Error(`Theme package has more than ${MAX_ENTRIES} root entries.`);
  const lowerNames = new Set();
  let totalBytes = 0;
  for (const name of names) {
    if (isMetadataName(name)) continue;
    const lower = name.toLowerCase();
    if (lowerNames.has(lower)) throw new Error(`Theme package contains case-colliding files: ${name}`);
    lowerNames.add(lower);
    const entry = path.join(packageRoot, name);
    const stat = await fs.lstat(entry);
    if (stat.isSymbolicLink() || !stat.isFile()) {
      throw new Error(`Theme packages may contain root files only; rejected: ${name}`);
    }
    if ((stat.mode & 0o111) !== 0) {
      throw new Error(`Theme package files must not be executable; rejected: ${name}`);
    }
    if (!referenced.has(name) && !DOCUMENT_FILES.has(name)) {
      throw new Error(`Theme package contains an unreferenced or unsupported file: ${name}`);
    }
    totalBytes += stat.size;
  }
  if (totalBytes > MAX_PACKAGE_BYTES) {
    throw new Error(`Theme package expands beyond ${MAX_PACKAGE_BYTES} bytes.`);
  }

  await assetStat(packageRoot, theme.image, MAX_THEME_BYTES, "theme.image");
  if (theme.avatars.user) await assetStat(packageRoot, theme.avatars.user, MAX_AVATAR_BYTES, "theme.avatars.user");
  if (theme.avatars.assistant) await assetStat(packageRoot, theme.avatars.assistant, MAX_AVATAR_BYTES, "theme.avatars.assistant");
  if (manifest.preview) await assetStat(packageRoot, manifest.preview, MAX_THEME_BYTES, "manifest.preview");
  return { packageRoot, manifest, theme, referenced, totalBytes };
}

function validateArchiveEntry(name) {
  if (!name || name.includes("\\") || name.includes("\0") || path.posix.isAbsolute(name)) {
    throw new Error(`Theme archive contains an unsafe path: ${JSON.stringify(name)}`);
  }
  const withoutSlash = name.endsWith("/") ? name.slice(0, -1) : name;
  const normalized = path.posix.normalize(withoutSlash);
  if (!normalized || normalized === "." || normalized === ".." || normalized.startsWith("../")) {
    throw new Error(`Theme archive contains an unsafe path: ${name}`);
  }
}

async function extractArchive(archive) {
  const archivePath = path.resolve(archive);
  const archiveStat = await fs.lstat(archivePath);
  if (!archiveStat.isFile() || archiveStat.isSymbolicLink() || archiveStat.size < 1 || archiveStat.size > MAX_ARCHIVE_BYTES) {
    throw new Error(`Theme archive must be a regular ZIP no larger than ${MAX_ARCHIVE_BYTES} bytes.`);
  }
  const names = execFileSync("/usr/bin/unzip", ["-Z1", archivePath], {
    encoding: "utf8",
    maxBuffer: 2 * 1024 * 1024,
  }).split(/\r?\n/).filter(Boolean);
  if (!names.length || names.length > MAX_ENTRIES) {
    throw new Error(`Theme archive must contain 1-${MAX_ENTRIES} entries.`);
  }
  for (const name of names) validateArchiveEntry(name);

  const listing = execFileSync("/usr/bin/zipinfo", ["-l", archivePath], {
    encoding: "utf8",
    maxBuffer: 2 * 1024 * 1024,
  });
  if (listing.split(/\r?\n/).some((line) => /^l[rwx-]{9}\s/.test(line))) {
    throw new Error("Theme archive contains a symbolic link, which is not allowed.");
  }
  let listedBytes = 0;
  for (const line of listing.split(/\r?\n/)) {
    const match = /^[d-][rwx-]{9}\s+\S+\s+\S+\s+(\d+)\s/.exec(line);
    if (match) listedBytes += Number(match[1]);
  }
  if (listedBytes > MAX_PACKAGE_BYTES) throw new Error("Theme archive declares too much uncompressed data.");

  const temporary = await fs.mkdtemp(path.join(os.tmpdir(), "codex-dream-theme-import."));
  try {
    execFileSync("/usr/bin/ditto", ["-x", "-k", archivePath, temporary], { stdio: "pipe" });
    const directManifest = path.join(temporary, "manifest.json");
    try {
      await fs.access(directManifest);
      return { temporary, packageRoot: temporary };
    } catch {}

    const entries = (await fs.readdir(temporary, { withFileTypes: true }))
      .filter((entry) => entry.name !== "__MACOSX" && !isMetadataName(entry.name));
    if (entries.length !== 1 || !entries[0].isDirectory()) {
      throw new Error("Theme ZIP must place manifest.json at its root or inside one top-level folder.");
    }
    const packageRoot = path.join(temporary, entries[0].name);
    await fs.access(path.join(packageRoot, "manifest.json"));
    return { temporary, packageRoot };
  } catch (error) {
    await fs.rm(temporary, { recursive: true, force: true });
    throw error;
  }
}

async function atomicWrite(file, value) {
  const temporary = `${file}.${process.pid}.tmp`;
  await fs.writeFile(temporary, value, { mode: 0o600 });
  await fs.rename(temporary, file);
  await fs.chmod(file, 0o600);
}

async function copyValidatedPackage(validated, destination) {
  const parent = path.dirname(destination);
  const temporary = path.join(parent, `.${path.basename(destination)}.importing.${process.pid}`);
  const previous = path.join(parent, `.${path.basename(destination)}.previous.${process.pid}`);
  await fs.mkdir(parent, { recursive: true, mode: 0o700 });
  await fs.rm(temporary, { recursive: true, force: true });
  await fs.rm(previous, { recursive: true, force: true });
  await fs.mkdir(temporary, { mode: 0o700 });
  try {
    await atomicWrite(path.join(temporary, "manifest.json"), `${JSON.stringify(validated.manifest, null, 2)}\n`);
    await atomicWrite(path.join(temporary, "theme.json"), `${JSON.stringify(validated.theme, null, 2)}\n`);
    const copied = new Set(["manifest.json", "theme.json"]);
    for (const name of validated.referenced) {
      if (copied.has(name)) continue;
      await fs.copyFile(path.join(validated.packageRoot, name), path.join(temporary, name));
      await fs.chmod(path.join(temporary, name), 0o600);
      copied.add(name);
    }
    for (const name of DOCUMENT_FILES) {
      try {
        await fs.copyFile(path.join(validated.packageRoot, name), path.join(temporary, name));
        await fs.chmod(path.join(temporary, name), 0o600);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
    }
    if (await fs.access(destination).then(() => true).catch(() => false)) {
      await fs.rename(destination, previous);
    }
    try {
      await fs.rename(temporary, destination);
      await fs.rm(previous, { recursive: true, force: true });
    } catch (error) {
      if (await fs.access(previous).then(() => true).catch(() => false)) {
        await fs.rename(previous, destination).catch(() => {});
      }
      throw error;
    }
  } finally {
    await fs.rm(temporary, { recursive: true, force: true });
    await fs.rm(previous, { recursive: true, force: true });
  }
}

async function importArchive() {
  const archive = valueFor("archive");
  if (!archive) throw new Error("Usage: theme-package.mjs import --archive <file.zip> [--library-only]");
  const themesDir = path.resolve(valueFor("themes-dir", path.join(defaultStateRoot, "themes")));
  const activeDir = path.resolve(valueFor("active-dir", path.join(defaultStateRoot, "theme")));
  const extracted = await extractArchive(archive);
  try {
    const validated = await validatePackageDirectory(extracted.packageRoot);
    const libraryDestination = path.join(themesDir, validated.manifest.id);
    await copyValidatedPackage(validated, libraryDestination);
    if (!hasFlag("library-only")) await copyValidatedPackage(validated, activeDir);
    return {
      action: "import",
      id: validated.manifest.id,
      name: validated.manifest.name,
      version: validated.manifest.version,
      layoutId: validated.theme.layoutId,
      installedAt: libraryDestination,
      activated: !hasFlag("library-only"),
    };
  } finally {
    await fs.rm(extracted.temporary, { recursive: true, force: true });
  }
}

async function loadExportSource(sourceDir) {
  const rawTheme = await readJson(path.join(sourceDir, "theme.json"), "theme.json");
  const theme = normalizeTheme(rawTheme, { source: path.join(sourceDir, "theme.json"), renderer, strict: false });
  const existing = await optionalJson(path.join(sourceDir, "manifest.json")) ?? {};
  const manifest = createThemePackageManifest(theme, { engineVersion, existing, author: "Codex Dream Skin 用户" });
  const normalizedManifest = validateThemePackageManifest(manifest, {
    theme,
    renderer,
    engineVersion,
    source: path.join(sourceDir, "manifest.json"),
  });
  const referenced = new Set(["manifest.json", "theme.json", theme.image]);
  if (theme.avatars.user) referenced.add(theme.avatars.user);
  if (theme.avatars.assistant) referenced.add(theme.avatars.assistant);
  if (normalizedManifest.preview) referenced.add(normalizedManifest.preview);
  await assetStat(sourceDir, theme.image, MAX_THEME_BYTES, "theme.image");
  if (theme.avatars.user) await assetStat(sourceDir, theme.avatars.user, MAX_AVATAR_BYTES, "theme.avatars.user");
  if (theme.avatars.assistant) await assetStat(sourceDir, theme.avatars.assistant, MAX_AVATAR_BYTES, "theme.avatars.assistant");
  return { packageRoot: sourceDir, manifest: normalizedManifest, theme, referenced };
}

async function exportArchive() {
  const outputValue = valueFor("output");
  if (!outputValue) throw new Error("Usage: theme-package.mjs export --output <file.zip> [--source-dir <theme-dir>]");
  const output = path.resolve(outputValue);
  if (path.extname(output).toLowerCase() !== ".zip") throw new Error("Theme package output must end in .zip.");
  let sourceDir = path.resolve(valueFor("source-dir", path.join(defaultStateRoot, "theme")));
  if (!(await fs.access(path.join(sourceDir, "theme.json")).then(() => true).catch(() => false))) {
    sourceDir = defaultThemeRoot;
  }
  const source = await loadExportSource(sourceDir);
  const temporary = await fs.mkdtemp(path.join(os.tmpdir(), "codex-dream-theme-export."));
  try {
    await atomicWrite(path.join(temporary, "manifest.json"), `${JSON.stringify(source.manifest, null, 2)}\n`);
    await atomicWrite(path.join(temporary, "theme.json"), `${JSON.stringify(source.theme, null, 2)}\n`);
    const copied = new Set(["manifest.json", "theme.json"]);
    for (const name of source.referenced) {
      if (copied.has(name)) continue;
      await fs.copyFile(path.join(source.packageRoot, name), path.join(temporary, name));
      copied.add(name);
    }
    await fs.mkdir(path.dirname(output), { recursive: true });
    await fs.rm(output, { force: true });
    execFileSync("/usr/bin/zip", ["-q", "-X", "-r", output, "."], { cwd: temporary, stdio: "pipe" });
    const size = (await fs.stat(output)).size;
    if (size < 1 || size > MAX_ARCHIVE_BYTES) throw new Error("Exported theme archive has an invalid size.");
    return {
      action: "export",
      id: source.manifest.id,
      name: source.manifest.name,
      version: source.manifest.version,
      output,
      bytes: size,
    };
  } finally {
    await fs.rm(temporary, { recursive: true, force: true });
  }
}

async function validateInput() {
  const archive = valueFor("archive");
  const directory = valueFor("directory");
  if (!archive && !directory) {
    throw new Error("Usage: theme-package.mjs validate (--archive <file.zip> | --directory <folder>)");
  }
  if (archive && directory) throw new Error("Pass either --archive or --directory, not both.");
  if (directory) {
    const validated = await validatePackageDirectory(directory);
    return { action: "validate", id: validated.manifest.id, name: validated.manifest.name, valid: true };
  }
  const extracted = await extractArchive(archive);
  try {
    const validated = await validatePackageDirectory(extracted.packageRoot);
    return { action: "validate", id: validated.manifest.id, name: validated.manifest.name, valid: true };
  } finally {
    await fs.rm(extracted.temporary, { recursive: true, force: true });
  }
}

let result;
if (mode === "import") result = await importArchive();
else if (mode === "export") result = await exportArchive();
else if (mode === "validate") result = await validateInput();
else throw new Error("Usage: theme-package.mjs <validate|import|export> [options]");
process.stdout.write(`${JSON.stringify(result)}\n`);
