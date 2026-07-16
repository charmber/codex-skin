import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = EngineController()
    private let menu = NSMenu()
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private var status = SkinStatus.empty
    private var isBusy = true
    private var deploymentError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        engine.deployBundledEngine { [weak self] result in
            guard let self else { return }
            self.isBusy = false
            if case .failure(let error) = result {
                self.deploymentError = error
                self.rebuildMenu()
                self.showError(title: "主题引擎不可用", detail: error.localizedDescription)
                return
            }
            self.refreshStatus()
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
            menu.addItem(infoItem("正在准备主题引擎..."))
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
            menu.addItem(actionItem("换一张图...", action: #selector(customizeTheme)))
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
        let palettes = NSMenu(title: "配色主题")
        for choice in engine.palettes() {
            let item = actionItem(choice.name, action: #selector(selectPalette))
            item.representedObject = choice.id
            item.state = choice.id == status.paletteId ? .on : .off
            palettes.addItem(item)
        }
        if palettes.items.isEmpty { palettes.addItem(infoItem("没有可用配色")) }
        let paletteParent = NSMenuItem(title: "配色主题", action: nil, keyEquivalent: "")
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
        isBusy = true
        deploymentError = nil
        rebuildMenu()
        engine.deployBundledEngine(force: true) { [weak self] result in
            guard let self else { return }
            self.isBusy = false
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
        runAction(title: "正在打开图片选择器...", script: "customize-theme-macos.sh")
    }

    @objc private func configureReadingPanel() {
        runAction(title: "正在打开阅读区设置...", script: "configure-reading-panel-macos.sh")
    }

    @objc private func customizeHeaderText() {
        runAction(title: "正在打开文字设置...", script: "customize-header-text-macos.sh")
    }

    @objc private func selectPalette(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        runAction(title: "正在切换配色...", script: "switch-palette-macos.sh", arguments: ["--id", id])
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
        successMessage: String? = nil
    ) {
        guard !isBusy else { return }
        isBusy = true
        menu.cancelTracking()
        statusItem.button?.title = "Skin ..."
        rebuildMenu()

        engine.runScript(script, arguments: arguments) { [weak self] result in
            guard let self else { return }
            self.isBusy = false
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
