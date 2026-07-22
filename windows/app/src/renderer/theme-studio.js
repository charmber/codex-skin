const colorFields = [
  ["background", "页面底色"], ["panel", "主面板"], ["panelAlt", "次面板"],
  ["accent", "主强调色"], ["accentAlt", "辅强调色"], ["secondary", "次要色"],
  ["highlight", "高亮色"], ["text", "主文字"], ["conversationText", "聊天记录文字"],
  ["muted", "次文字"],
];

const defaults = {
  name: "我的新主题",
  backgroundName: "我的背景",
  paletteId: "custom",
  paletteName: "自定义配色",
  layoutId: "stage",
  visualStyle: "portal",
  brandSubtitle: "CODEX DREAM SKIN",
  tagline: "把喜欢的画面变成可交互的 Codex 工作台。",
  projectPrefix: "选择项目 · ",
  projectLabel: "选择项目",
  statusText: "DREAM SKIN ONLINE",
  quote: "MAKE SOMETHING WONDERFUL",
  effects: { taskPanelOpacity: 0.76, taskPanelBlur: 14 },
  headerText: { title: "", subtitle: "", status: "" },
  colors: {
    background: "#071116", panel: "#0b1a20", panelAlt: "#10272c", accent: "#39c5bb",
    accentAlt: "#68e3d9", secondary: "#58c9ee", highlight: "#ff6f91", text: "#f2fff7",
    conversationText: "#f2fff7", muted: "#a7c2ba", line: "rgba(57, 197, 187, 0.30)",
  },
  layoutComponents: {
    retroHeader: true, toolbar: true, threePane: true, autoOpenSummary: true, companion: true,
    profileCard: true, homePet: true, minWidth: 1180, rightWidth: 300, windowTitle: "Codex 2007",
    profileName: "", profileStatus: "在线", companionTitle: "Codex 伙伴", companionStatus: "在线 · 随时待命",
  },
};

const $ = (selector) => document.querySelector(selector);
let current = structuredClone(defaults);
let choices = { layouts: [], palettes: [] };
let saving = false;

function setStatus(message, tone = "") {
  const node = $("#footer-status");
  node.textContent = message;
  node.dataset.tone = tone;
}

function setAsset(kind, asset) {
  const key = kind === "background" ? "imageAsset" : `${kind}AvatarAsset`;
  current[key] = asset;
  const prefix = kind === "background" ? "background" : `${kind}-avatar`;
  const image = $(`#${prefix}-image`);
  const empty = $(`#${prefix}-empty`);
  if (asset?.dataUrl) {
    image.src = asset.dataUrl;
    image.style.display = "block";
    empty.style.display = "none";
  } else {
    image.removeAttribute("src");
    image.style.display = "none";
    empty.style.display = kind === "background" ? "grid" : "inline";
  }
  if (kind !== "background") $(`#${prefix}-path`).textContent = asset?.path || "未设置";
}

function createColorFields() {
  const grid = $("#color-grid");
  for (const [key, label] of colorFields) {
    const wrapper = document.createElement("label");
    wrapper.className = "color-field";
    wrapper.innerHTML = `<input type="color" id="color-${key}"><strong>${label}</strong><code id="color-${key}-value"></code>`;
    grid.append(wrapper);
    const input = wrapper.querySelector("input");
    input.addEventListener("input", () => { wrapper.querySelector("code").textContent = input.value; });
  }
  const line = document.createElement("label");
  line.className = "color-field line-color-field";
  line.innerHTML = `<strong>边框与分隔线</strong><input id="color-line" maxlength="40" spellcheck="false">`;
  grid.append(line);
}

function renderLayouts() {
  const container = $("#layout-options");
  container.replaceChildren();
  for (const layout of choices.layouts) {
    const label = document.createElement("label");
    label.className = "segment";
    label.innerHTML = `<input type="radio" name="layout" value="${layout.id}"><span>${layout.name}</span>`;
    container.append(label);
  }
  const selected = container.querySelector(`input[value="${CSS.escape(current.layoutId)}"]`) || container.querySelector("input");
  if (selected) selected.checked = true;
  container.addEventListener("change", () => {
    const layoutId = container.querySelector("input:checked")?.value || "stage";
    current.layoutId = layoutId;
    current.visualStyle = layoutId === "qq-classic" ? "classic-blue-07" : "portal";
    updateComponentState();
  });
}

function value(id) { return $(`#${id}`).value; }
function setValue(id, next) { $(`#${id}`).value = next ?? ""; }
function checked(id) { return $(`#${id}`).checked; }
function setChecked(id, next) { $(`#${id}`).checked = Boolean(next); }

function populate(theme) {
  current = { ...structuredClone(defaults), ...theme };
  current.colors = { ...defaults.colors, ...(theme.colors || {}) };
  current.effects = { ...defaults.effects, ...(theme.effects || {}) };
  current.headerText = { ...defaults.headerText, ...(theme.headerText || {}) };
  current.layoutComponents = { ...defaults.layoutComponents, ...(theme.layoutComponents || {}) };
  setValue("name", current.name);
  setValue("background-name", current.backgroundName);
  setValue("palette-name", current.paletteName);
  setValue("brand-subtitle", current.brandSubtitle);
  setValue("tagline", current.tagline);
  setValue("project-prefix", current.projectPrefix);
  setValue("project-label", current.projectLabel);
  setValue("status-text", current.statusText);
  setValue("quote", current.quote);
  setValue("header-title", current.headerText.title);
  setValue("header-subtitle", current.headerText.subtitle);
  setValue("header-status", current.headerText.status);
  $("#task-opacity").value = Math.round(current.effects.taskPanelOpacity * 100);
  $("#task-blur").value = current.effects.taskPanelBlur;
  updateSliderLabels();
  for (const [key] of colorFields) {
    const input = $(`#color-${key}`);
    input.value = /^#[0-9a-f]{6}$/i.test(current.colors[key]) ? current.colors[key] : defaults.colors[key];
    $(`#color-${key}-value`).textContent = input.value;
  }
  setValue("color-line", current.colors.line);
  const components = current.layoutComponents;
  setChecked("retro-header", components.retroHeader);
  setChecked("toolbar", components.toolbar);
  setChecked("three-pane", components.threePane);
  setChecked("auto-summary", components.autoOpenSummary);
  setChecked("companion", components.companion);
  setChecked("profile-card", components.profileCard);
  setChecked("home-pet", components.homePet);
  setValue("layout-min-width", components.minWidth);
  setValue("layout-right-width", components.rightWidth);
  setValue("layout-window-title", components.windowTitle);
  setValue("layout-profile-name", components.profileName);
  setValue("layout-profile-status", components.profileStatus);
  setValue("layout-companion-title", components.companionTitle);
  setValue("layout-companion-status", components.companionStatus);
  renderLayouts();
  setAsset("background", current.imageAsset || null);
  setAsset("user", current.userAvatarAsset || null);
  setAsset("assistant", current.assistantAvatarAsset || null);
  updatePreviewText();
  updateComponentState();
}

function updateSliderLabels() {
  $("#opacity-value").textContent = `${$("#task-opacity").value}%`;
  $("#blur-value").textContent = `${$("#task-blur").value} px`;
}

function updatePreviewText() {
  $("#preview-title").textContent = value("name") || "Codex Dream Skin";
  $("#preview-subtitle").textContent = value("status-text") || "DREAM SKIN ONLINE";
}

function updateComponentState() {
  const isClassic = current.layoutId === "qq-classic";
  $("#component-layout-label").textContent = isClassic ? "经典蓝 QQ 工作台" : "仅经典蓝布局生效";
  document.querySelectorAll("[data-panel='components'] input").forEach((input) => { input.disabled = !isClassic; });
}

function collectDraft() {
  const layoutId = $("#layout-options input:checked")?.value || current.layoutId || "stage";
  return {
    name: value("name").trim(),
    backgroundName: value("background-name").trim(),
    paletteId: current.paletteId || "custom",
    paletteName: value("palette-name").trim(),
    layoutId,
    visualStyle: layoutId === "qq-classic" ? "classic-blue-07" : current.visualStyle || "portal",
    brandSubtitle: value("brand-subtitle"),
    tagline: value("tagline"),
    projectPrefix: value("project-prefix"),
    projectLabel: value("project-label"),
    statusText: value("status-text"),
    quote: value("quote"),
    imagePath: current.imageAsset?.path || null,
    userAvatarPath: current.userAvatarAsset?.path || null,
    assistantAvatarPath: current.assistantAvatarAsset?.path || null,
    effects: { taskPanelOpacity: Number($("#task-opacity").value) / 100, taskPanelBlur: Number($("#task-blur").value) },
    headerText: { title: value("header-title"), subtitle: value("header-subtitle"), status: value("header-status") },
    colors: Object.fromEntries([
      ...colorFields.map(([key]) => [key, $(`#color-${key}`).value]),
      ["line", value("color-line").trim()],
    ]),
    layoutComponents: {
      retroHeader: checked("retro-header"), toolbar: checked("toolbar"), threePane: checked("three-pane"),
      autoOpenSummary: checked("auto-summary"), companion: checked("companion"), profileCard: checked("profile-card"),
      homePet: checked("home-pet"), minWidth: Number(value("layout-min-width")), rightWidth: Number(value("layout-right-width")),
      windowTitle: value("layout-window-title"), profileName: value("layout-profile-name"), profileStatus: value("layout-profile-status"),
      companionTitle: value("layout-companion-title"), companionStatus: value("layout-companion-status"),
    },
  };
}

function setSaving(next) {
  saving = next;
  $("#save-only").disabled = next;
  $("#save-apply").disabled = next;
  $("#apply-current").disabled = next;
}

async function save(applyImmediately) {
  if (saving) return;
  const draft = collectDraft();
  if (!draft.name) return setStatus("请填写主题名称", "error");
  if (!draft.imagePath) return setStatus("请先选择背景图片", "error");
  setSaving(true);
  setStatus(applyImmediately ? "正在保存并应用..." : "正在保存...");
  try {
    const result = await window.dreamSkin.save(draft, applyImmediately);
    const data = await window.dreamSkin.load();
    choices = data.choices;
    populate(data.theme);
    if (result.applyError) {
      setStatus(`主题已保存，但应用失败：${result.applyError}`, "error");
    } else {
      setStatus(applyImmediately && result.applied === false ? "主题已保存，已取消应用" : applyImmediately ? "主题已保存并应用" : "主题已保存", "success");
    }
    $("#save-state").textContent = "已保存";
  } catch (error) {
    setStatus(error.message || String(error), "error");
  } finally {
    setSaving(false);
  }
}

function registerEvents() {
  document.querySelectorAll(".nav-item[data-tab]").forEach((button) => button.addEventListener("click", () => {
    document.querySelectorAll(".nav-item[data-tab]").forEach((item) => item.classList.toggle("active", item === button));
    document.querySelectorAll(".tab-panel").forEach((panel) => panel.classList.toggle("active", panel.dataset.panel === button.dataset.tab));
  }));
  $("#task-opacity").addEventListener("input", updateSliderLabels);
  $("#task-blur").addEventListener("input", updateSliderLabels);
  $("#name").addEventListener("input", updatePreviewText);
  $("#status-text").addEventListener("input", updatePreviewText);
  $("#choose-background").addEventListener("click", async () => {
    const asset = await window.dreamSkin.chooseBackground();
    if (!asset) return;
    setAsset("background", asset);
    if (!value("background-name") || value("background-name") === "我的背景") {
      const filename = asset.path.split(/[\\/]/).pop().replace(/\.[^.]+$/, "");
      setValue("background-name", filename);
    }
  });
  for (const role of ["user", "assistant"]) {
    $(`#choose-${role}-avatar`).addEventListener("click", async () => {
      const asset = await window.dreamSkin.chooseAvatar(role);
      if (asset) setAsset(role, asset);
    });
    $(`#remove-${role}-avatar`).addEventListener("click", () => setAsset(role, null));
  }
  $("#new-theme").addEventListener("click", () => {
    const imageAsset = current.imageAsset || null;
    populate({ ...structuredClone(defaults), imageAsset });
    $("#save-state").textContent = "新主题尚未保存";
    setStatus("新主题");
  });
  $("#save-only").addEventListener("click", () => save(false));
  $("#save-apply").addEventListener("click", () => save(true));
  $("#apply-current").addEventListener("click", async () => {
    setSaving(true);
    setStatus("正在应用当前主题...");
    try {
      const applied = await window.dreamSkin.apply();
      setStatus(applied === false ? "已取消应用" : "当前主题已应用", applied === false ? "" : "success");
    }
    catch (error) { setStatus(error.message || String(error), "error"); }
    finally { setSaving(false); }
  });
  $("#open-images").addEventListener("click", () => window.dreamSkin.openFolder("images"));
  $("#open-logs").addEventListener("click", () => window.dreamSkin.openFolder("logs"));
}

async function initialize() {
  createColorFields();
  registerEvents();
  try {
    const data = await window.dreamSkin.load();
    choices = data.choices;
    $("#version").textContent = `v${data.version}`;
    const status = $("#engine-status");
    status.textContent = data.status.session === "active" ? "皮肤已启用" : data.status.session === "paused" ? "皮肤已暂停" : "皮肤未启用";
    status.classList.toggle("active", data.status.session === "active");
    status.classList.toggle("warning", data.status.session === "stale");
    populate(data.theme);
  } catch (error) {
    setStatus(error.message || String(error), "error");
  }
}

initialize();
