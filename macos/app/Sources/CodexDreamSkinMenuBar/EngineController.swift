import Foundation
import Darwin

final class EngineController {
    private let fileManager = FileManager.default
    private let workQueue = DispatchQueue(label: "com.charmber.codexdreamskin.engine", qos: .userInitiated)
    private let processLock = NSLock()
    private var runningProcessIdentifier: pid_t?
    private var cancelledProcessIdentifiers = Set<pid_t>()

    let installRoot: URL
    let stateRoot: URL

    var imagesDirectory: URL { stateRoot.appendingPathComponent("images", isDirectory: true) }
    var themesDirectory: URL { stateRoot.appendingPathComponent("themes", isDirectory: true) }
    var logsDirectory: URL { stateRoot }
    var isInitialized: Bool {
        fileManager.fileExists(atPath: stateRoot.appendingPathComponent("theme-backup.json").path)
    }

    init() {
        let home = fileManager.homeDirectoryForCurrentUser
        installRoot = home
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("codex-dream-skin-studio", isDirectory: true)
        stateRoot = home
            .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio", isDirectory: true)
    }

    func deployBundledEngine(force: Bool = false, completion: @escaping (Result<Void, Error>) -> Void) {
        workQueue.async {
            do {
                try self.deployBundledEngine(force: force)
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private func deployBundledEngine(force: Bool) throws {
        guard let resources = Bundle.main.resourceURL else {
            throw EngineError.bundledEngineMissing("Contents/Resources")
        }
        let bundled = resources.appendingPathComponent("Engine", isDirectory: true)
        let bundledVersionURL = bundled.appendingPathComponent("VERSION")
        guard fileManager.fileExists(atPath: bundledVersionURL.path) else {
            throw EngineError.bundledEngineMissing(bundled.path)
        }

        let bundledVersion = try version(at: bundledVersionURL)
        let installedVersionURL = installRoot.appendingPathComponent("VERSION")
        if !force,
           let installedVersion = try? version(at: installedVersionURL),
           compareVersions(installedVersion, bundledVersion) != .orderedAscending {
            try prepareStateDirectories()
            return
        }

        let parent = installRoot.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let token = UUID().uuidString
        let temporary = parent.appendingPathComponent("codex-dream-skin-studio.installing.\(token)", isDirectory: true)
        let previous = parent.appendingPathComponent("codex-dream-skin-studio.previous.\(token)", isDirectory: true)

        try? fileManager.removeItem(at: temporary)
        try? fileManager.removeItem(at: previous)

        do {
            try fileManager.copyItem(at: bundled, to: temporary)
            try makeScriptsExecutable(in: temporary)

            if fileManager.fileExists(atPath: installRoot.path) {
                try fileManager.moveItem(at: installRoot, to: previous)
            }

            do {
                try fileManager.moveItem(at: temporary, to: installRoot)
                try? fileManager.removeItem(at: previous)
            } catch {
                if fileManager.fileExists(atPath: previous.path),
                   !fileManager.fileExists(atPath: installRoot.path) {
                    try? fileManager.moveItem(at: previous, to: installRoot)
                }
                throw error
            }
            try prepareStateDirectories()
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw EngineError.deploymentFailed(error.localizedDescription)
        }
    }

    private func prepareStateDirectories() throws {
        try fileManager.createDirectory(at: stateRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: themesDirectory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stateRoot.path)
    }

    private func makeScriptsExecutable(in root: URL) throws {
        let scripts = root.appendingPathComponent("scripts", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: scripts,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let file as URL in enumerator where file.pathExtension == "sh" {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        }
    }

    private func version(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }

    func runScript(
        _ name: String,
        arguments: [String] = [],
        timeout: TimeInterval? = 90,
        completion: @escaping (Result<ScriptResult, Error>) -> Void
    ) {
        workQueue.async {
            let script = self.installRoot
                .appendingPathComponent("scripts", isDirectory: true)
                .appendingPathComponent(name)
            guard self.fileManager.isExecutableFile(atPath: script.path) else {
                DispatchQueue.main.async {
                    completion(.failure(EngineError.scriptMissing(script.path)))
                }
                return
            }

            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [script.path] + arguments
            process.currentDirectoryURL = self.installRoot
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            process.environment = self.processEnvironment()

            do {
                let termination = DispatchSemaphore(value: 0)
                let outputFinished = DispatchSemaphore(value: 0)
                let outputLock = NSLock()
                var outputData = Data()
                process.terminationHandler = { _ in termination.signal() }
                try process.run()
                let processID = process.processIdentifier
                _ = setpgid(processID, processID)
                self.processLock.lock()
                self.runningProcessIdentifier = processID
                self.processLock.unlock()

                DispatchQueue.global(qos: .utility).async {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    outputLock.lock()
                    outputData.append(data)
                    outputLock.unlock()
                    outputFinished.signal()
                }

                let timedOut: Bool
                if let timeout {
                    timedOut = termination.wait(timeout: .now() + timeout) == .timedOut
                } else {
                    termination.wait()
                    timedOut = false
                }

                if timedOut {
                    self.signalProcessTree(processID, signal: SIGTERM)
                    if termination.wait(timeout: .now() + 2) == .timedOut {
                        self.signalProcessTree(processID, signal: SIGKILL)
                        _ = termination.wait(timeout: .now() + 2)
                    }
                }

                if outputFinished.wait(timeout: .now() + 1) == .timedOut {
                    outputPipe.fileHandleForReading.closeFile()
                    _ = outputFinished.wait(timeout: .now() + 1)
                }
                outputLock.lock()
                let data = outputData
                outputLock.unlock()
                let wasCancelled = self.finishProcess(processID)
                let output = String(data: data, encoding: .utf8) ?? ""
                if timedOut {
                    DispatchQueue.main.async {
                        completion(.failure(EngineError.scriptTimedOut(name, Int(timeout?.rounded() ?? 0))))
                    }
                    return
                }
                if wasCancelled {
                    DispatchQueue.main.async { completion(.failure(EngineError.scriptCancelled(name))) }
                    return
                }
                let result = ScriptResult(exitCode: process.terminationStatus, output: output)
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func cancelRunningScript() {
        processLock.lock()
        let processID = runningProcessIdentifier
        if let processID { cancelledProcessIdentifiers.insert(processID) }
        processLock.unlock()
        guard let processID else { return }
        signalProcessTree(processID, signal: SIGTERM)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.processLock.lock()
            let stillRunning = self.runningProcessIdentifier == processID
            self.processLock.unlock()
            if stillRunning { self.signalProcessTree(processID, signal: SIGKILL) }
        }
    }

    private func signalProcessTree(_ processID: pid_t, signal: Int32) {
        if kill(-processID, signal) != 0 { _ = kill(processID, signal) }
    }

    private func finishProcess(_ processID: pid_t) -> Bool {
        processLock.lock()
        defer { processLock.unlock() }
        if runningProcessIdentifier == processID { runningProcessIdentifier = nil }
        return cancelledProcessIdentifiers.remove(processID) != nil
    }

    func loadStatus(completion: @escaping (SkinStatus) -> Void) {
        runScript("status-dream-skin-macos.sh", arguments: ["--json"], timeout: 5) { result in
            guard case .success(let scriptResult) = result,
                  scriptResult.succeeded,
                  let data = scriptResult.output.data(using: .utf8),
                  let status = try? JSONDecoder().decode(SkinStatus.self, from: data) else {
                completion(.empty)
                return
            }
            completion(status)
        }
    }

    func palettes() -> [NamedChoice] {
        let root = installRoot.appendingPathComponent("palettes", isDirectory: true)
        return jsonChoices(in: root, fallbackToFilename: true)
    }

    func palettes(for layoutId: String) -> [NamedChoice] {
        palettes().filter { ($0.layoutId ?? "stage") == layoutId }
    }

    func layouts() -> [NamedChoice] {
        let root = installRoot.appendingPathComponent("layouts", isDirectory: true)
        return jsonChoices(in: root, fallbackToFilename: true)
    }

    func backgrounds() -> [NamedChoice] {
        let supported = Set(["png", "jpg", "jpeg", "webp", "heic", "tif", "tiff"])
        let urls = (try? fileManager.contentsOfDirectory(
            at: imagesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { supported.contains($0.pathExtension.lowercased()) }
            .map { NamedChoice(id: $0.lastPathComponent, name: $0.lastPathComponent) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func historicalThemes() -> [NamedChoice] {
        jsonChoices(in: themesDirectory, nestedThemeFile: true, fallbackToFilename: true)
    }

    func loadActiveTheme() throws -> ThemeDraft {
        let userTheme = stateRoot
            .appendingPathComponent("theme", isDirectory: true)
            .appendingPathComponent("theme.json")
        let bundledTheme = installRoot
            .appendingPathComponent("themes", isDirectory: true)
            .appendingPathComponent("builtin-miku-aqua", isDirectory: true)
            .appendingPathComponent("theme.json")
        let themeURL = fileManager.fileExists(atPath: userTheme.path) ? userTheme : bundledTheme

        do {
            let data = try Data(contentsOf: themeURL)
            let theme = try JSONDecoder().decode(ThemeFile.self, from: data)
            let assetURL: (String?) -> URL? = { name in
                guard let name, !name.isEmpty, URL(fileURLWithPath: name).lastPathComponent == name else {
                    return nil
                }
                let candidate = themeURL.deletingLastPathComponent().appendingPathComponent(name)
                return self.fileManager.fileExists(atPath: candidate.path) ? candidate : nil
            }
            let imageURL = assetURL(theme.image)
            let defaults = ThemeDraft.blank
            return ThemeDraft(
                name: theme.name ?? defaults.name,
                backgroundName: theme.backgroundName ?? theme.image ?? defaults.backgroundName,
                visualStyle: theme.visualStyle ?? defaults.visualStyle,
                layoutId: theme.layoutId ?? (theme.visualStyle == "classic-blue-07" ? "qq-classic" : defaults.layoutId),
                layoutComponents: theme.layoutComponents ?? defaults.layoutComponents,
                brandSubtitle: theme.brandSubtitle ?? defaults.brandSubtitle,
                tagline: theme.tagline ?? defaults.tagline,
                projectPrefix: theme.projectPrefix ?? defaults.projectPrefix,
                projectLabel: theme.projectLabel ?? defaults.projectLabel,
                statusText: theme.statusText ?? defaults.statusText,
                quote: theme.quote ?? defaults.quote,
                imageURL: imageURL,
                userAvatarURL: assetURL(theme.avatars?.user),
                assistantAvatarURL: assetURL(theme.avatars?.assistant),
                colors: theme.colors ?? defaults.colors,
                effects: theme.effects ?? defaults.effects,
                headerText: theme.headerText ?? defaults.headerText
            )
        } catch {
            throw EngineError.themeUnavailable(error.localizedDescription)
        }
    }

    func saveTheme(
        _ draft: ThemeDraft,
        applyImmediately: Bool,
        completion: @escaping (Result<ScriptResult, Error>) -> Void
    ) {
        guard let imageURL = draft.imageURL else {
            completion(.failure(EngineError.themeUnavailable("请先选择一张背景图片。")))
            return
        }
        let colors = draft.colors
        var arguments = [
            "--image", imageURL.path,
            "--name", draft.name,
            "--background-name", draft.backgroundName,
            "--visual-style", draft.visualStyle,
            "--layout-id", draft.layoutId,
            "--brand-subtitle", draft.brandSubtitle,
            "--tagline", draft.tagline,
            "--project-prefix", draft.projectPrefix,
            "--project-label", draft.projectLabel,
            "--status-text", draft.statusText,
            "--quote", draft.quote,
            "--background-color", colors.background,
            "--panel-color", colors.panel,
            "--panel-alt-color", colors.panelAlt,
            "--accent", colors.accent,
            "--accent-alt", colors.accentAlt,
            "--secondary", colors.secondary,
            "--highlight", colors.highlight,
            "--text-color", colors.text,
            "--muted-color", colors.muted,
            "--line-color", colors.line,
            "--task-panel-opacity", String(draft.effects.taskPanelOpacity * 100),
            "--task-panel-blur", String(draft.effects.taskPanelBlur),
            "--header-title", draft.headerText.title ?? "",
            "--header-subtitle", draft.headerText.subtitle ?? "",
            "--header-status", draft.headerText.status ?? "",
            "--component-retro-header", String(draft.layoutComponents.retroHeader),
            "--component-toolbar", String(draft.layoutComponents.toolbar),
            "--component-three-pane", String(draft.layoutComponents.threePane),
            "--component-auto-open-summary", String(draft.layoutComponents.autoOpenSummary),
            "--component-companion", String(draft.layoutComponents.companion),
            "--component-profile-card", String(draft.layoutComponents.profileCard),
            "--component-home-pet", String(draft.layoutComponents.homePet),
            "--layout-min-width", String(draft.layoutComponents.minWidth),
            "--layout-right-width", String(draft.layoutComponents.rightWidth),
            "--layout-window-title", draft.layoutComponents.windowTitle,
            "--layout-profile-name", draft.layoutComponents.profileName,
            "--layout-profile-status", draft.layoutComponents.profileStatus,
            "--layout-companion-title", draft.layoutComponents.companionTitle,
            "--layout-companion-status", draft.layoutComponents.companionStatus,
            "--save-theme"
        ]
        if let userAvatarURL = draft.userAvatarURL {
            arguments.append(contentsOf: ["--user-avatar", userAvatarURL.path])
        } else {
            arguments.append("--clear-user-avatar")
        }
        if let assistantAvatarURL = draft.assistantAvatarURL {
            arguments.append(contentsOf: ["--assistant-avatar", assistantAvatarURL.path])
        } else {
            arguments.append("--clear-assistant-avatar")
        }
        if !applyImmediately { arguments.append("--no-apply") }
        runScript("customize-theme-macos.sh", arguments: arguments, completion: completion)
    }

    private func jsonChoices(
        in directory: URL,
        nestedThemeFile: Bool = false,
        fallbackToFilename: Bool
    ) -> [NamedChoice] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { url in
            let jsonURL: URL
            let fallbackID: String
            if nestedThemeFile {
                jsonURL = url.appendingPathComponent("theme.json")
                fallbackID = url.lastPathComponent
            } else {
                guard url.pathExtension.lowercased() == "json" else { return nil }
                jsonURL = url
                fallbackID = url.deletingPathExtension().lastPathComponent
            }
            guard let data = try? Data(contentsOf: jsonURL),
                  let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let id = nestedThemeFile
                ? fallbackID
                : (value["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackID
            let name = (value["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? (fallbackToFilename ? fallbackID : id)
            let layoutId = (value["layoutId"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return NamedChoice(id: id, name: name, layoutId: layoutId)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = fileManager.homeDirectoryForCurrentUser.path
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        environment["LANG"] = environment["LANG"] ?? "zh_CN.UTF-8"
        return environment
    }
}
