((cssText, artDataUrl, themeConfig) => {
  const STATE_KEY = "__CODEX_DREAM_SKIN_STATE__";
  const DISABLED_KEY = "__CODEX_DREAM_SKIN_DISABLED__";
  const STYLE_ID = "codex-dream-skin-style";
  const CHROME_ID = "codex-dream-skin-chrome";
  const SHELL_ATTR = "data-dream-shell";
  const THEME_ATTR = "data-dream-theme";
  const PALETTE_ATTR = "data-dream-palette";
  const VERSION = __DREAM_SKIN_VERSION_JSON__;
  const THEME = themeConfig && typeof themeConfig === "object" ? themeConfig : {};
  const THEME_VARIABLES = [
    "--ds-bg", "--ds-panel", "--ds-panel-2", "--ds-green", "--ds-lime",
    "--ds-cyan", "--ds-purple", "--ds-text", "--ds-conversation-text", "--ds-muted", "--ds-line",
    "--dream-skin-name", "--dream-skin-tagline", "--dream-skin-project-prefix",
    "--dream-skin-project-label", "--dream-skin-user-avatar", "--dream-skin-assistant-avatar",
    "--ds-task-panel-opacity-strong",
    "--ds-task-panel-opacity", "--ds-task-panel-opacity-soft", "--ds-task-panel-blur",
  ];
  const qqState = window.__CODEX_QQ_SKIN_STATE__;
  if (qqState?.cleanup) {
    try { qqState.cleanup(); } catch {}
  }
  window.__CODEX_QQ_SKIN_DISABLED__ = true;
  window[DISABLED_KEY] = false;

  const previous = window[STATE_KEY];
  if (previous?.observer) previous.observer.disconnect();
  if (previous?.timer) clearInterval(previous.timer);
  if (previous?.scheduler?.timeout) clearTimeout(previous.scheduler.timeout);
  if (previous?.resizeHandler) window.removeEventListener("resize", previous.resizeHandler);
  if (previous?.mediaHandler && previous?.mediaQuery) {
    try { previous.mediaQuery.removeEventListener("change", previous.mediaHandler); } catch {}
  }
  if (previous?.artUrl) URL.revokeObjectURL(previous.artUrl);

  const artUrl = (() => {
    const comma = artDataUrl.indexOf(",");
    const mime = /^data:([^;,]+)/.exec(artDataUrl)?.[1] || "image/png";
    const binary = atob(artDataUrl.slice(comma + 1));
    const bytes = new Uint8Array(binary.length);
    for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
    return URL.createObjectURL(new Blob([bytes], { type: mime }));
  })();

  const cssString = (value) => JSON.stringify(String(value ?? ""));

  const parseRgb = (value) => {
    if (!value || value === "transparent") return null;
    const m = String(value).match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
    if (!m) return null;
    return { r: Number(m[1]), g: Number(m[2]), b: Number(m[3]) };
  };

  const luminance = ({ r, g, b }) => {
    const lin = [r, g, b].map((c) => {
      const x = c / 255;
      return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
  };

  /** Detect Codex app light/dark shell for CSS branching. */
  const detectShellMode = () => {
    const root = document.documentElement;
    const body = document.body;
    const cls = `${root.className || ""} ${body?.className || ""}`.toLowerCase();

    if (/\b(dark|theme-dark|appearance-dark)\b/.test(cls)) return "dark";
    if (/\b(light|theme-light|appearance-light)\b/.test(cls)) return "light";

    const dataTheme = (
      root.getAttribute("data-theme") ||
      root.getAttribute("data-appearance") ||
      root.getAttribute("data-color-mode") ||
      body?.getAttribute("data-theme") ||
      body?.getAttribute("data-appearance") ||
      ""
    ).toLowerCase();
    if (dataTheme.includes("dark")) return "dark";
    if (dataTheme.includes("light")) return "light";

    // Radios in profile menu (if present in DOM)
    const checked = document.querySelector('input[name="appearance-theme"]:checked');
    if (checked) {
      const label = (checked.getAttribute("aria-label") || checked.value || "").toLowerCase();
      if (label.includes("暗") || label.includes("dark")) return "dark";
      if (label.includes("浅") || label.includes("light")) return "light";
      if (label.includes("系统") || label.includes("system")) {
        return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
      }
    }

    try {
      const cs = getComputedStyle(root).colorScheme || "";
      if (cs.includes("dark") && !cs.includes("light")) return "dark";
      if (cs.includes("light") && !cs.includes("dark")) return "light";
    } catch {}

    // Background luminance of main surfaces
    const samples = [
      body,
      document.querySelector("main.main-surface"),
      document.querySelector("aside.app-shell-left-panel"),
    ].filter(Boolean);
    let votesLight = 0;
    let votesDark = 0;
    for (const el of samples) {
      try {
        const rgb = parseRgb(getComputedStyle(el).backgroundColor);
        if (!rgb) continue;
        const L = luminance(rgb);
        if (L >= 0.55) votesLight += 1;
        else if (L <= 0.25) votesDark += 1;
      } catch {}
    }
    if (votesLight > votesDark) return "light";
    if (votesDark > votesLight) return "dark";

    try {
      if (window.matchMedia("(prefers-color-scheme: dark)").matches) return "dark";
    } catch {}
    return "light";
  };

  const applyTheme = (root, shell) => {
    const colors = THEME.colors || {};
    const opacity = Number.isFinite(Number(THEME.effects?.taskPanelOpacity))
      ? Math.min(1, Math.max(0, Number(THEME.effects.taskPanelOpacity)))
      : 0.76;
    const blur = Number.isFinite(Number(THEME.effects?.taskPanelBlur))
      ? Math.min(40, Math.max(0, Number(THEME.effects.taskPanelBlur)))
      : 14;
    const accent = colors.accent || (shell === "light" ? "#e25563" : "#7cff46");
    const accentAlt = colors.accentAlt || accent;
    const secondary = colors.secondary || (shell === "light" ? "#f3a8af" : "#36d7e8");
    const highlight = colors.highlight || (shell === "light" ? "#c93d4c" : "#642a8c");

    let variables;
    if (shell === "light") {
      variables = {
        "--ds-bg": colors.background || "#f6f2f3",
        "--ds-panel": colors.panel || "#ffffff",
        "--ds-panel-2": colors.panelAlt || "#fff7f8",
        "--ds-green": accent,
        "--ds-lime": accentAlt,
        "--ds-cyan": secondary,
        "--ds-purple": highlight,
        "--ds-text": colors.text || "#1f1a1b",
        "--ds-conversation-text": colors.conversationText || colors.text || "#1f1a1b",
        "--ds-muted": colors.muted || "#6b5f62",
        "--ds-line": colors.line || "rgba(196, 120, 128, .22)",
      };
    } else {
      variables = {
        "--ds-bg": colors.background || "#071116",
        "--ds-panel": colors.panel || "#0b1a20",
        "--ds-panel-2": colors.panelAlt || "#10272c",
        "--ds-green": accent,
        "--ds-lime": accentAlt,
        "--ds-cyan": secondary,
        "--ds-purple": highlight,
        "--ds-text": colors.text || "#e9fff1",
        "--ds-conversation-text": colors.conversationText || colors.text || "#e9fff1",
        "--ds-muted": colors.muted || "#9ebdb3",
        "--ds-line": colors.line || "rgba(124, 255, 70, .28)",
      };
    }

    for (const [name, value] of Object.entries(variables)) {
      if (typeof value === "string" && value) root.style.setProperty(name, value);
    }
    root.style.setProperty("--ds-task-panel-opacity-strong", `${Math.round(Math.min(1, opacity + 0.18) * 100)}%`);
    root.style.setProperty("--ds-task-panel-opacity", `${Math.round(opacity * 100)}%`);
    root.style.setProperty("--ds-task-panel-opacity-soft", `${Math.round(Math.max(0, opacity - 0.21) * 100)}%`);
    root.style.setProperty("--ds-task-panel-blur", `${Math.round(blur * 10) / 10}px`);
    root.style.setProperty("--dream-skin-name", cssString(THEME.name || "Codex Dream Skin"));
    root.style.setProperty("--dream-skin-tagline", cssString(typeof THEME.tagline === "string" ? THEME.tagline : "Make something wonderful."));
    root.style.setProperty("--dream-skin-project-prefix", cssString(typeof THEME.projectPrefix === "string" ? THEME.projectPrefix : "选择项目 · "));
    root.style.setProperty("--dream-skin-project-label", cssString(typeof THEME.projectLabel === "string" ? THEME.projectLabel : "◉  选择项目"));
    const avatarDataUrls = THEME.avatarDataUrls || {};
    for (const [role, variable] of [
      ["user", "--dream-skin-user-avatar"],
      ["assistant", "--dream-skin-assistant-avatar"],
    ]) {
      const dataUrl = avatarDataUrls[role];
      if (typeof dataUrl === "string" && dataUrl.startsWith("data:image/")) {
        root.style.setProperty(variable, `url("${dataUrl}")`);
      } else {
        root.style.removeProperty(variable);
      }
    }
  };

  const existingStyle = document.getElementById(STYLE_ID);
  if (existingStyle) {
    existingStyle.textContent = cssText;
    existingStyle.dataset.dreamSkinVersion = VERSION;
  }

  const projectControlText = (node) => `${
    node?.getAttribute?.("aria-label") || ""
  } ${node?.getAttribute?.("title") || ""} ${node?.textContent || ""}`
    .replace(/\s+/g, " ").trim().toLowerCase();

  const findProjectButton = (home) => {
    if (!home) return null;
    const legacyButton = home.querySelector('.group\\/project-selector > button');
    if (legacyButton) return legacyButton;
    return [...home.querySelectorAll('button, [role="button"]')].find((candidate) => {
      const label = projectControlText(candidate);
      return label.includes("选择项目") || label.includes("select project") || label.includes("choose project");
    }) || null;
  };

  const markProjectSelector = (home) => {
    const projectButton = findProjectButton(home);
    const legacyGroup = projectButton?.closest('.group\\/project-selector');
    const projectShell = legacyGroup?.closest(".horizontal-scroll-fade-mask")?.parentElement ||
      projectButton?.parentElement || null;
    for (const candidate of document.querySelectorAll(".dream-skin-project-button")) {
      if (candidate !== projectButton) candidate.classList.remove("dream-skin-project-button");
    }
    for (const candidate of document.querySelectorAll(".dream-skin-project-shell")) {
      if (candidate !== projectShell) candidate.classList.remove("dream-skin-project-shell");
    }
    projectButton?.classList.add("dream-skin-project-button");
    projectShell?.classList.add("dream-skin-project-shell");
    return projectButton;
  };

  const messageRole = (node) => {
    const key = node?.getAttribute?.("data-content-search-unit-key") || "";
    if (key.endsWith(":user")) return "user";
    if (key.endsWith(":assistant")) return "assistant";
    const author = node?.getAttribute?.("data-message-author-role") || "";
    return author === "user" || author === "assistant" ? author : null;
  };

  const markChatAvatars = () => {
    const dataUrls = THEME.avatarDataUrls || {};
    const modernMessages = [...document.querySelectorAll("[data-content-search-unit-key]")];
    const candidates = modernMessages.length > 0
      ? modernMessages
      : [...document.querySelectorAll('[data-message-author-role="user"], [data-message-author-role="assistant"]')];
    const active = new Set();
    for (const message of candidates) {
      const role = messageRole(message);
      if (!role || typeof dataUrls[role] !== "string" || !dataUrls[role].startsWith("data:image/")) continue;
      active.add(message);
      message.classList.add("dream-skin-chat-message", `dream-skin-chat-message-${role}`);
      message.classList.remove(`dream-skin-chat-message-${role === "user" ? "assistant" : "user"}`);
      let avatar = [...message.children].find((child) => child.classList?.contains("dream-skin-chat-avatar"));
      if (!avatar) {
        avatar = document.createElement("span");
        avatar.className = "dream-skin-chat-avatar";
        avatar.setAttribute("aria-hidden", "true");
        message.appendChild(avatar);
      }
      avatar.classList.toggle("dream-skin-chat-avatar-user", role === "user");
      avatar.classList.toggle("dream-skin-chat-avatar-assistant", role === "assistant");
    }
    for (const message of document.querySelectorAll(".dream-skin-chat-message")) {
      if (active.has(message)) continue;
      message.classList.remove(
        "dream-skin-chat-message",
        "dream-skin-chat-message-user",
        "dream-skin-chat-message-assistant"
      );
      [...message.children]
        .filter((child) => child.classList?.contains("dream-skin-chat-avatar"))
        .forEach((avatar) => avatar.remove());
    }
  };

  const ensure = () => {
    if (window[DISABLED_KEY]) return;
    const root = document.documentElement;
    if (!root) return;
    const shell = detectShellMode();
    root.classList.add("codex-dream-skin");
    root.setAttribute(SHELL_ATTR, shell);
    root.setAttribute(THEME_ATTR, THEME.visualStyle || "portal");
    root.setAttribute(PALETTE_ATTR, THEME.paletteId || "custom");
    root.style.setProperty("--dream-skin-art", `url("${artUrl}")`);
    applyTheme(root, shell);

    let style = document.getElementById(STYLE_ID);
    if (!style) {
      style = document.createElement("style");
      style.id = STYLE_ID;
      (document.head || root).appendChild(style);
    }
    if (style.dataset.dreamSkinVersion !== VERSION) {
      style.textContent = cssText;
      style.dataset.dreamSkinVersion = VERSION;
    }

    const shellMain = document.querySelector("main.main-surface") || document.querySelector("main");
    const homeIndicator = document.querySelector('[data-testid="home-icon"]');
    const home = homeIndicator?.closest('[role="main"]') ||
      [...document.querySelectorAll('[role="main"]')].find((candidate) =>
        candidate.querySelector('[data-feature="game-source"]') &&
        candidate.querySelector('[class~="group/home-suggestions"]')) || null;
    for (const candidate of document.querySelectorAll('[role="main"].dream-skin-home')) {
      if (candidate !== home) candidate.classList.remove("dream-skin-home");
    }
    if (home) home.classList.add("dream-skin-home");
    markProjectSelector(home);
    markChatAvatars();

    if (!shellMain || !document.body) return;
    shellMain.classList.toggle("dream-skin-home-shell", Boolean(home));
    let chrome = document.getElementById(CHROME_ID);
    if (!chrome || chrome.parentElement !== document.body || chrome.dataset.dreamChromeVersion !== VERSION) {
      chrome?.remove();
      chrome = document.createElement("div");
      chrome.id = CHROME_ID;
      chrome.dataset.dreamChromeVersion = VERSION;
      chrome.setAttribute("aria-hidden", "true");
      chrome.innerHTML = `
        <div class="dream-skin-brand" aria-hidden="true">
          <span class="dream-skin-portal-mark">◉</span>
          <span><b></b><small></small></span>
        </div>
        <div class="dream-skin-status" aria-hidden="true"><i></i><span></span></div>
        <div class="dream-skin-quote" aria-hidden="true"></div>
        <div class="dream-skin-particles" aria-hidden="true"><i></i><i></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
        <div class="dream-skin-orbit" aria-hidden="true"></div>
        <nav class="dream-classic-toolbar" aria-label="经典蓝快捷工具栏">
          <button type="button" data-dream-action="new"><span>＋</span><b>新建任务</b></button>
          <button type="button" data-dream-action="search"><span>⌕</span><b>搜索</b></button>
          <button type="button" data-dream-action="scheduled"><span>◷</span><b>已安排</b></button>
          <button type="button" data-dream-action="review"><span>⎇</span><b>代码审查</b></button>
          <button type="button" data-dream-action="skills"><span>✦</span><b>技能</b></button>
        </nav>
        <aside class="dream-classic-rail" aria-hidden="true">
          <section class="dream-classic-card dream-classic-assistant">
            <header><span>◉</span><b>Codex 助手</b><span class="dream-classic-collapse">⌃</span></header>
            <div class="dream-classic-portrait">
              <div class="dream-classic-bot">
                <i class="dream-classic-antenna"></i>
                <div class="dream-classic-bot-head"><span>&gt;</span><span>_</span></div>
                <div class="dream-classic-bot-body">&gt;_</div>
              </div>
            </div>
            <div class="dream-classic-assistant-copy">
              <div><i></i><b>Codex 小蓝</b><em>LV 07</em></div>
              <p></p>
            </div>
          </section>
          <section class="dream-classic-card dream-classic-theme-card">
            <header><span>◆</span><b>当前主题</b><span class="dream-classic-collapse">⌃</span></header>
            <dl>
              <div><dt>主题</dt><dd class="dream-classic-theme-value"></dd></div>
              <div><dt>配色</dt><dd class="dream-classic-palette-value"></dd></div>
              <div><dt>背景</dt><dd class="dream-classic-background-value"></dd></div>
            </dl>
          </section>
          <section class="dream-classic-card dream-classic-runtime-card">
            <header><span>◷</span><b>运行状态</b><span class="dream-classic-collapse">⌃</span></header>
            <dl>
              <div><dt>本机回环</dt><dd>127.0.0.1</dd></div>
              <div><dt>热更新</dt><dd class="dream-classic-ok">可用</dd></div>
              <div><dt>状态</dt><dd class="dream-classic-status-value"></dd></div>
            </dl>
          </section>
        </aside>`;
      document.body.appendChild(chrome);
    }
    const classicMode = THEME.visualStyle === "classic-blue-07";
    const classicToolbar = chrome.querySelector(".dream-classic-toolbar");
    if (classicMode) chrome.removeAttribute("aria-hidden");
    else chrome.setAttribute("aria-hidden", "true");
    if (classicToolbar) classicToolbar.hidden = !classicMode;
    if (classicToolbar && !classicToolbar.dataset.dreamActionsBound) {
      const labelsByAction = {
        new: ["新建任务", "new task"],
        search: ["搜索", "search"],
        scheduled: ["已安排", "scheduled", "automations"],
        review: ["代码审查", "code review"],
        skills: ["技能", "skills"],
      };
      classicToolbar.addEventListener("click", (event) => {
        const button = event.target.closest("button[data-dream-action]");
        if (!button) return;
        const labels = labelsByAction[button.dataset.dreamAction] || [];
        const candidates = [...document.querySelectorAll(
          'aside.app-shell-left-panel button, aside.app-shell-left-panel a'
        )];
        const target = candidates.find((candidate) => {
          const value = `${candidate.getAttribute("aria-label") || ""} ${candidate.textContent || ""}`
            .replace(/\s+/g, " ").trim().toLowerCase();
          return labels.some((label) => value.includes(label));
        });
        if (target) {
          event.preventDefault();
          target.click();
        }
      });
      classicToolbar.dataset.dreamActionsBound = "true";
    }
    const headerText = THEME.headerText || {};
    chrome.querySelector(".dream-skin-brand b").textContent = typeof headerText.title === "string"
      ? headerText.title : (THEME.name || "Codex Dream Skin");
    chrome.querySelector(".dream-skin-brand small").textContent = typeof headerText.subtitle === "string"
      ? headerText.subtitle : (typeof THEME.brandSubtitle === "string" ? THEME.brandSubtitle : "CODEX DREAM SKIN");
    chrome.querySelector(".dream-skin-status span").textContent = typeof headerText.status === "string"
      ? headerText.status : (typeof THEME.statusText === "string" ? THEME.statusText : "DREAM SKIN ONLINE");
    chrome.querySelector(".dream-skin-quote").textContent = typeof THEME.quote === "string"
      ? THEME.quote : "MAKE SOMETHING WONDERFUL";
    const classicAssistantCopy = chrome.querySelector(".dream-classic-assistant-copy p");
    const classicThemeValue = chrome.querySelector(".dream-classic-theme-value");
    const classicPaletteValue = chrome.querySelector(".dream-classic-palette-value");
    const classicBackgroundValue = chrome.querySelector(".dream-classic-background-value");
    const classicStatusValue = chrome.querySelector(".dream-classic-status-value");
    if (classicAssistantCopy) classicAssistantCopy.textContent = `正在使用“${THEME.name || "经典蓝工作台"}”。`;
    if (classicThemeValue) classicThemeValue.textContent = THEME.name || "经典蓝工作台";
    if (classicPaletteValue) classicPaletteValue.textContent = THEME.paletteName || "自定义配色";
    if (classicBackgroundValue) classicBackgroundValue.textContent = THEME.backgroundName || "当前背景";
    if (classicStatusValue) classicStatusValue.textContent = typeof headerText.status === "string"
      ? headerText.status : (typeof THEME.statusText === "string" ? THEME.statusText : "已连接");
    const shellBox = shellMain.getBoundingClientRect();
    chrome.style.left = `${Math.round(shellBox.left)}px`;
    chrome.style.top = `${Math.round(shellBox.top)}px`;
    chrome.style.width = `${Math.round(shellBox.width)}px`;
    chrome.style.height = `${Math.round(shellBox.height)}px`;
    chrome.classList.toggle("dream-skin-home-shell", Boolean(home));
    chrome.dataset.dreamShell = shell;
  };

  const cleanup = () => {
    window[DISABLED_KEY] = true;
    document.documentElement?.classList.remove("codex-dream-skin");
    document.documentElement?.removeAttribute(SHELL_ATTR);
    document.documentElement?.removeAttribute(THEME_ATTR);
    document.documentElement?.removeAttribute(PALETTE_ATTR);
    document.documentElement?.style.removeProperty("--dream-skin-art");
    for (const name of THEME_VARIABLES) document.documentElement?.style.removeProperty(name);
    document.querySelectorAll(".dream-skin-home").forEach((node) => node.classList.remove("dream-skin-home"));
    document.querySelectorAll(".dream-skin-home-shell").forEach((node) => node.classList.remove("dream-skin-home-shell"));
    document.querySelectorAll(".dream-skin-project-button").forEach((node) => node.classList.remove("dream-skin-project-button"));
    document.querySelectorAll(".dream-skin-project-shell").forEach((node) => node.classList.remove("dream-skin-project-shell"));
    document.querySelectorAll(".dream-skin-chat-message").forEach((node) => {
      node.classList.remove("dream-skin-chat-message", "dream-skin-chat-message-user", "dream-skin-chat-message-assistant");
    });
    document.querySelectorAll(".dream-skin-chat-avatar").forEach((node) => node.remove());
    document.getElementById(STYLE_ID)?.remove();
    document.getElementById(CHROME_ID)?.remove();
    const state = window[STATE_KEY];
    state?.observer?.disconnect();
    if (state?.timer) clearInterval(state.timer);
    if (state?.scheduler?.timeout) clearTimeout(state.scheduler.timeout);
    if (state?.resizeHandler) window.removeEventListener("resize", state.resizeHandler);
    if (state?.mediaHandler && state?.mediaQuery) {
      try { state.mediaQuery.removeEventListener("change", state.mediaHandler); } catch {}
    }
    if (state?.artUrl) URL.revokeObjectURL(state.artUrl);
    delete window[STATE_KEY];
    return true;
  };

  const scheduler = { timeout: null };
  const scheduleEnsure = () => {
    if (scheduler.timeout) clearTimeout(scheduler.timeout);
    scheduler.timeout = setTimeout(() => {
      scheduler.timeout = null;
      ensure();
    }, 180);
  };
  const observer = new MutationObserver(scheduleEnsure);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["class", "data-theme", "data-appearance", "data-color-mode", "style"],
  });
  const timer = setInterval(ensure, 4000);
  const resizeHandler = scheduleEnsure;
  window.addEventListener("resize", resizeHandler, { passive: true });

  let mediaQuery = null;
  let mediaHandler = null;
  try {
    mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    mediaHandler = () => scheduleEnsure();
    mediaQuery.addEventListener("change", mediaHandler);
  } catch {}

  window[STATE_KEY] = {
    ensure,
    cleanup,
    observer,
    timer,
    scheduler,
    resizeHandler,
    mediaQuery,
    mediaHandler,
    artUrl,
    version: VERSION,
    themeId: THEME.id || "custom",
    visualStyle: THEME.visualStyle || "portal",
    paletteId: THEME.paletteId || "custom",
    avatars: {
      user: Boolean(THEME.avatarDataUrls?.user),
      assistant: Boolean(THEME.avatarDataUrls?.assistant),
    },
    effects: THEME.effects || { taskPanelOpacity: 0.76, taskPanelBlur: 14 },
    headerText: THEME.headerText || {},
    detectShellMode,
  };
  ensure();
  return {
    installed: true,
    version: VERSION,
    themeId: THEME.id || "custom",
    visualStyle: THEME.visualStyle || "portal",
    paletteId: THEME.paletteId || "custom",
    avatars: {
      user: Boolean(THEME.avatarDataUrls?.user),
      assistant: Boolean(THEME.avatarDataUrls?.assistant),
    },
    effects: THEME.effects || { taskPanelOpacity: 0.76, taskPanelBlur: 14 },
    shell: detectShellMode(),
  };
})(__DREAM_SKIN_CSS_JSON__, __DREAM_SKIN_ART_JSON__, __DREAM_SKIN_THEME_JSON__)
