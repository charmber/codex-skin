import AppKit
import ServiceManagement
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = EngineController()
    private let menu = NSMenu()
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var status = SkinStatus.empty
    private var isBusy = true
    private var busyMessage = "正在准备主题引擎..."
    private var busyToken: UUID?
    private var busyWatchdog: DispatchWorkItem?
    private var busyIsDeployment = true
    private var deploymentError: Error?
    private var themeEditor: ThemeEditorWindowController?
    private let shouldOpenThemeEditor = CommandLine.arguments.contains("--open-theme-editor") ||
        ProcessInfo.processInfo.environment["CODEX_DREAM_SKIN_OPEN_EDITOR"] == "1"
    private var themeStoreURL: URL {
        let productionURL = URL(string: "https://skin.beanplay.cn")!
        guard let configured = ProcessInfo.processInfo.environment["CODEX_DREAM_SKIN_STORE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !configured.isEmpty,
              let candidate = URL(string: configured),
              let scheme = candidate.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              candidate.host != nil else {
            return productionURL
        }
        return candidate
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        let deploymentToken = beginBusy(message: "正在准备主题引擎...", timeout: 45, isDeployment: true)
        engine.deployBundledEngine { [weak self] result in
            guard let self else { return }
            guard self.finishBusy(deploymentToken) else { return }
            if case .failure(let error) = result {
                self.deploymentError = error
                self.rebuildMenu()
                self.showError(title: "主题引擎不可用", detail: error.localizedDescription)
                return
            }
            self.refreshStatus()
            if self.shouldOpenThemeEditor { self.openThemeEditor() }
            self.warnWhenRunningFromDiskImage()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatus()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "paintpalette.fill", accessibilityDescription: "Codex Dream Skin")
        button.imagePosition = .imageLeading
        button.title = "Skin"
        button.toolTip = "Codex Dream Skin"
    }

    private func refreshStatus() {
        guard !isBusy, deploymentError == nil else { return }
        engine.loadStatus { [weak self] status in
            guard let self else { return }
            self.status = status
            self.updateStatusItem()
            self.rebuildMenu()
        }
    }

    private func updateStatusItem() {
        let title: String
        switch status.session {
        case "active": title = "Skin ON"
        case "paused": title = "Skin PAUSE"
        case "stale", "unknown": title = "Skin ?"
        default: title = "Skin"
        }
        statusItem.button?.title = title
        statusItem.button?.toolTip = "Codex Dream Skin - \(title)"
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        if isBusy {
            menu.addItem(infoItem(busyMessage))
            if !busyIsDeployment {
                let cancel = NSMenuItem(title: "取消当前操作", action: #selector(cancelCurrentOperation), keyEquivalent: "")
                cancel.target = self
                cancel.isEnabled = true
                menu.addItem(cancel)
            }
            return
        }

        if let deploymentError {
            menu.addItem(infoItem("主题引擎加载失败"))
            menu.addItem(actionItem("重试", action: #selector(retryDeployment)))
            menu.addItem(.separator())
            menu.addItem(actionItem("退出", action: #selector(quit)))
            statusItem.button?.title = "Skin !"
            statusItem.button?.toolTip = deploymentError.localizedDescription
            return
        }

        menu.addItem(infoItem(sessionSummary))
        menu.addItem(infoItem("布局：\(status.layoutName)"))
        if !status.paletteName.isEmpty {
            menu.addItem(infoItem("配色：\(status.paletteName)"))
        }
        if !status.backgroundName.isEmpty {
            menu.addItem(infoItem("背景：\(status.backgroundName)"))
        }
        menu.addItem(infoItem(status.codexRunning ? "Codex：已打开" : "Codex：未打开"))
        menu.addItem(.separator())

        if !engine.isInitialized {
            menu.addItem(infoItem("首次使用需要初始化"))
            menu.addItem(actionItem("初始化主题引擎...", action: #selector(initializeEngine)))
        } else {
            menu.addItem(actionItem("应用皮肤...", action: #selector(applySkin)))
            menu.addItem(actionItem("暂停皮肤", action: #selector(pauseSkin)))
            menu.addItem(actionItem("打开主题工作室...", action: #selector(openThemeEditor)))
            menu.addItem(actionItem("打开主题商店...", action: #selector(openThemeStore)))
            menu.addItem(actionItem("导入主题包...", action: #selector(importThemePackage)))
            menu.addItem(actionItem("导出当前主题...", action: #selector(exportThemePackage)))
            menu.addItem(actionItem("快速换背景图...", action: #selector(customizeTheme)))
            menu.addItem(actionItem(
                "阅读区：\(format(status.taskPanelOpacityPercent))% / \(format(status.taskPanelBlur))px",
                action: #selector(configureReadingPanel)
            ))
            menu.addItem(actionItem("自定义顶部文字...", action: #selector(customizeHeaderText)))
            addChoiceMenus()
            menu.addItem(.separator())
            menu.addItem(actionItem("完全恢复官方外观...", action: #selector(restoreOfficialAppearance)))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("打开背景文件夹", action: #selector(openBackgrounds)))
        menu.addItem(actionItem("打开日志文件夹", action: #selector(openLogs)))

        let loginItem = actionItem("登录时启动", action: #selector(toggleLaunchAtLogin))
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        if SMAppService.mainApp.status == .requiresApproval {
            menu.addItem(actionItem("在系统设置中允许登录项...", action: #selector(openLoginItemSettings)))
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("关于 Codex Dream Skin", action: #selector(showAbout)))
        menu.addItem(actionItem("退出菜单栏应用", action: #selector(quit)))
    }

    private var sessionSummary: String {
        switch status.session {
        case "active": return "状态：皮肤已启用"
        case "paused": return "状态：皮肤已暂停"
        case "stale": return "状态：需要重新应用"
        case "unknown": return "状态：未知"
        default: return "状态：皮肤未启用"
        }
    }

    private func addChoiceMenus() {
        let layouts = NSMenu(title: "布局主题")
        for choice in engine.layouts() {
            let item = actionItem(choice.name, action: #selector(selectLayout))
            item.representedObject = choice.id
            item.state = choice.id == status.layoutId ? .on : .off
            layouts.addItem(item)
        }
        if layouts.items.isEmpty { layouts.addItem(infoItem("没有可用布局")) }
        let layoutParent = NSMenuItem(title: "布局主题", action: nil, keyEquivalent: "")
        layoutParent.submenu = layouts
        menu.addItem(layoutParent)

        let palettes = NSMenu(title: "配色方案")
        for choice in engine.palettes(for: status.layoutId) {
            let item = actionItem(choice.name, action: #selector(selectPalette))
            item.representedObject = choice.id
            item.state = choice.id == status.paletteId ? .on : .off
            palettes.addItem(item)
        }
        if palettes.items.isEmpty { palettes.addItem(infoItem("没有可用配色")) }
        let paletteParent = NSMenuItem(title: "配色方案", action: nil, keyEquivalent: "")
        paletteParent.submenu = palettes
        menu.addItem(paletteParent)

        let backgrounds = NSMenu(title: "背景图片")
        for choice in engine.backgrounds() {
            let item = actionItem(choice.name, action: #selector(selectBackground))
            item.representedObject = choice.id
            item.state = choice.id == status.backgroundName ? .on : .off
            backgrounds.addItem(item)
        }
        if backgrounds.items.isEmpty { backgrounds.addItem(infoItem("背景文件夹为空")) }
        backgrounds.addItem(.separator())
        backgrounds.addItem(actionItem("打开背景文件夹", action: #selector(openBackgrounds)))
        let backgroundParent = NSMenuItem(title: "背景图片", action: nil, keyEquivalent: "")
        backgroundParent.submenu = backgrounds
        menu.addItem(backgroundParent)

        let themes = engine.historicalThemes()
        if !themes.isEmpty {
            let historical = NSMenu(title: "历史组合")
            for choice in themes {
                let item = actionItem(choice.name, action: #selector(selectHistoricalTheme))
                item.representedObject = choice.id
                item.state = choice.name == status.themeName ? .on : .off
                historical.addItem(item)
            }
            let historicalParent = NSMenuItem(title: "历史组合", action: nil, keyEquivalent: "")
            historicalParent.submenu = historical
            menu.addItem(historicalParent)
        }
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = !isBusy
        return item
    }

    private func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    @objc private func retryDeployment() {
        deploymentError = nil
        let token = beginBusy(message: "正在重新部署主题引擎...", timeout: 45, isDeployment: true)
        engine.deployBundledEngine(force: true) { [weak self] result in
            guard let self else { return }
            guard self.finishBusy(token) else { return }
            if case .failure(let error) = result { self.deploymentError = error }
            self.refreshStatus()
            self.rebuildMenu()
        }
    }

    @objc private func initializeEngine() {
        runAction(
            title: "正在初始化...",
            script: "install-dream-skin-macos.sh",
            arguments: ["--in-place", "--no-launchers", "--no-launch"],
            successMessage: "初始化完成。现在可以从菜单栏点击“应用皮肤”。"
        )
    }

    @objc private func applySkin() {
        runAction(title: "正在应用皮肤...", script: "apply-from-menubar-macos.sh")
    }

    @objc private func pauseSkin() {
        runAction(title: "正在暂停皮肤...", script: "pause-dream-skin-macos.sh")
    }

    @objc private func customizeTheme() {
        runAction(title: "正在打开图片选择器...", script: "customize-theme-macos.sh", timeout: nil)
    }

    @objc private func openThemeEditor() {
        menu.cancelTracking()
        if themeEditor == nil {
            themeEditor = ThemeEditorWindowController(engine: engine) { [weak self] in
                self?.refreshStatus()
            }
        }
        themeEditor?.present()
    }

    @objc private func openThemeStore() {
        menu.cancelTracking()
        guard NSWorkspace.shared.open(themeStoreURL) else {
            showError(title: "无法打开主题商店", detail: themeStoreURL.absoluteString)
            return
        }
    }

    @objc private func importThemePackage() {
        menu.cancelTracking()
        let panel = NSOpenPanel()
        panel.title = "导入 Codex Dream Skin 主题包"
        panel.message = "选择 .cds-theme.zip 主题包。导入前会校验格式、素材和渲染器兼容性。"
        panel.prompt = "导入并应用"
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runAction(
            title: "正在校验并导入主题包...",
            script: "import-theme-package-macos.sh",
            arguments: ["--file", url.path],
            successMessage: "主题包已加入主题库并应用。"
        )
    }

    @objc private func exportThemePackage() {
        menu.cancelTracking()
        let panel = NSSavePanel()
        panel.title = "导出当前 Codex Dream Skin 主题"
        panel.message = "导出的 ZIP 包含完整主题配置和图片素材，不包含渲染器代码。"
        panel.prompt = "导出"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedThemePackageFilename
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runAction(
            title: "正在导出主题包...",
            script: "export-theme-package-macos.sh",
            arguments: ["--output", url.path],
            timeout: 45,
            successMessage: "主题包已导出到：\n\(url.path)"
        )
    }

    private var suggestedThemePackageFilename: String {
        let source = status.themeName.isEmpty ? "Codex-Dream-Skin-Theme" : status.themeName
        let sanitized = source
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sanitized.isEmpty ? "Codex-Dream-Skin-Theme" : sanitized
        return "\(base).cds-theme.zip"
    }

    @objc private func configureReadingPanel() {
        runAction(title: "正在打开阅读区设置...", script: "configure-reading-panel-macos.sh", timeout: nil)
    }

    @objc private func customizeHeaderText() {
        runAction(title: "正在打开文字设置...", script: "customize-header-text-macos.sh", timeout: nil)
    }

    @objc private func selectPalette(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        runAction(title: "正在切换配色...", script: "switch-palette-macos.sh", arguments: ["--id", id])
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        runAction(title: "正在切换布局...", script: "switch-layout-macos.sh", arguments: ["--id", id])
    }

    @objc private func selectBackground(_ sender: NSMenuItem) {
        guard let filename = sender.representedObject as? String else { return }
        runAction(
            title: "正在切换背景...",
            script: "load-image-theme-macos.sh",
            arguments: ["--from-library", filename]
        )
    }

    @objc private func selectHistoricalTheme(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        runAction(title: "正在切换历史主题...", script: "switch-theme-macos.sh", arguments: ["--id", id])
    }

    @objc private func restoreOfficialAppearance() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "完全恢复官方外观？"
        alert.informativeText = "这会停止主题注入、恢复已备份的外观设置，并重启 Codex。你的背景图片和配色文件会保留。"
        alert.addButton(withTitle: "恢复并重启")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runAction(
            title: "正在恢复官方外观...",
            script: "restore-dream-skin-macos.sh",
            arguments: ["--restore-base-theme", "--restart-codex"]
        )
    }

    private func runAction(
        title: String,
        script: String,
        arguments: [String] = [],
        timeout: TimeInterval? = 120,
        successMessage: String? = nil
    ) {
        guard !isBusy else { return }
        menu.cancelTracking()
        let token = beginBusy(message: title, timeout: timeout.map { $0 + 7 }, isDeployment: false)

        engine.runScript(script, arguments: arguments, timeout: timeout) { [weak self] result in
            guard let self else { return }
            guard self.finishBusy(token) else { return }
            switch result {
            case .success(let scriptResult) where scriptResult.succeeded:
                if let successMessage { self.showInformation(title: title, detail: successMessage) }
            case .success(let scriptResult):
                let detail = self.trimmedOutput(scriptResult.output, fallback: "脚本退出码：\(scriptResult.exitCode)")
                self.showError(title: "操作失败", detail: detail)
            case .failure(let error):
                self.showError(title: "操作失败", detail: error.localizedDescription)
            }
            self.refreshStatus()
        }
    }

    @discardableResult
    private func beginBusy(message: String, timeout: TimeInterval?, isDeployment: Bool) -> UUID {
        busyWatchdog?.cancel()
        let token = UUID()
        busyToken = token
        busyMessage = message
        busyIsDeployment = isDeployment
        isBusy = true
        statusItem.button?.title = "Skin ..."
        statusItem.button?.toolTip = message
        if let timeout {
            let watchdog = DispatchWorkItem { [weak self] in
                guard let self, self.busyToken == token else { return }
                self.engine.cancelRunningScript()
                self.busyToken = nil
                self.busyWatchdog = nil
                self.isBusy = false
                self.busyMessage = ""
                if isDeployment {
                    self.deploymentError = EngineError.deploymentFailed("准备过程超过 \(Int(timeout)) 秒，已恢复菜单。")
                }
                self.updateStatusItem()
                self.rebuildMenu()
                if !isDeployment {
                    self.showError(title: "操作超时", detail: "\(message)超过 \(Int(timeout)) 秒，相关子进程已停止，菜单已恢复。")
                }
            }
            busyWatchdog = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: watchdog)
        }
        rebuildMenu()
        return token
    }

    private func finishBusy(_ token: UUID) -> Bool {
        guard busyToken == token else { return false }
        busyWatchdog?.cancel()
        busyWatchdog = nil
        busyToken = nil
        busyMessage = ""
        isBusy = false
        return true
    }

    @objc private func cancelCurrentOperation() {
        guard busyToken != nil, !busyIsDeployment else { return }
        busyWatchdog?.cancel()
        busyWatchdog = nil
        busyToken = nil
        busyMessage = ""
        isBusy = false
        engine.cancelRunningScript()
        updateStatusItem()
        rebuildMenu()
        refreshStatus()
    }

    private func trimmedOutput(_ output: String, fallback: String) -> String {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return fallback }
        return String(value.suffix(800))
    }

    @objc private func openBackgrounds() {
        NSWorkspace.shared.open(engine.imagesDirectory)
    }

    @objc private func openLogs() {
        NSWorkspace.shared.open(engine.logsDirectory)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                guard !Bundle.main.bundleURL.path.hasPrefix("/Volumes/") else {
                    showError(title: "请先安装应用", detail: "请把 Codex Dream Skin 拖入“应用程序”文件夹，再启用登录时启动。")
                    return
                }
                try SMAppService.mainApp.register()
            }
            rebuildMenu()
        } catch {
            showError(title: "登录项设置失败", detail: error.localizedDescription)
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    @objc private func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        showInformation(
            title: "Codex Dream Skin \(version)",
            detail: "非 OpenAI 官方产品。通过本机回环 CDP 应用主题，不修改官方 Codex.app、app.asar 或代码签名。"
        )
    }

    private func warnWhenRunningFromDiskImage() {
        guard Bundle.main.bundleURL.path.hasPrefix("/Volumes/") else { return }
        showInformation(
            title: "请先拖入应用程序文件夹",
            detail: "当前应用仍在 DMG 中。请退出后将 Codex Dream Skin 拖入“应用程序”文件夹，再重新打开。"
        )
    }

    private func showInformation(title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError(title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
