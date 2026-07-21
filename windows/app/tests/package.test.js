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
