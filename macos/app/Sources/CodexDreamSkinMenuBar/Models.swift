import Foundation

struct SkinStatus: Decodable {
    let session: String
    let port: Int
    let injectorAlive: Bool
    let cdpOk: Bool
    let codexRunning: Bool
    let themeName: String
    let paletteId: String
    let paletteName: String
    let backgroundName: String
    let taskPanelOpacityPercent: Double
    let taskPanelBlur: Double

    static let empty = SkinStatus(
        session: "off",
        port: 9341,
        injectorAlive: false,
        cdpOk: false,
        codexRunning: false,
        themeName: "",
        paletteId: "",
        paletteName: "",
        backgroundName: "",
        taskPanelOpacityPercent: 76,
        taskPanelBlur: 14
    )
}

struct NamedChoice {
    let id: String
    let name: String
}

struct ThemeColors: Decodable {
    var background: String
    var panel: String
    var panelAlt: String
    var accent: String
    var accentAlt: String
    var secondary: String
    var highlight: String
    var text: String
    var muted: String
    var line: String

    static let portal = ThemeColors(
        background: "#071116",
        panel: "#0b1a20",
        panelAlt: "#10272c",
        accent: "#7cff46",
        accentAlt: "#b8ff3d",
        secondary: "#36d7e8",
        highlight: "#642a8c",
        text: "#f2fff7",
        muted: "#a7c2ba",
        line: "rgba(124, 255, 70, 0.32)"
    )
}

struct ThemeEffects: Decodable {
    var taskPanelOpacity: Double
    var taskPanelBlur: Double

    static let standard = ThemeEffects(taskPanelOpacity: 0.76, taskPanelBlur: 14)
}

struct ThemeHeaderText: Decodable {
    var title: String?
    var subtitle: String?
    var status: String?

    static let empty = ThemeHeaderText(title: "", subtitle: "", status: "")
}

struct ThemeFile: Decodable {
    let name: String?
    let backgroundName: String?
    let visualStyle: String?
    let brandSubtitle: String?
    let tagline: String?
    let projectPrefix: String?
    let projectLabel: String?
    let statusText: String?
    let quote: String?
    let image: String?
    let effects: ThemeEffects?
    let headerText: ThemeHeaderText?
    let colors: ThemeColors?
}

struct ThemeDraft {
    var name: String
    var backgroundName: String
    var visualStyle: String
    var brandSubtitle: String
    var tagline: String
    var projectPrefix: String
    var projectLabel: String
    var statusText: String
    var quote: String
    var imageURL: URL?
    var colors: ThemeColors
    var effects: ThemeEffects
    var headerText: ThemeHeaderText

    static let blank = ThemeDraft(
        name: "我的新主题",
        backgroundName: "我的背景",
        visualStyle: "portal",
        brandSubtitle: "CODEX DREAM SKIN",
        tagline: "把喜欢的画面变成可交互的 Codex 工作台。",
        projectPrefix: "选择项目 · ",
        projectLabel: "选择项目",
        statusText: "DREAM SKIN ONLINE",
        quote: "MAKE SOMETHING WONDERFUL",
        imageURL: nil,
        colors: .portal,
        effects: .standard,
        headerText: .empty
    )
}

struct ScriptResult {
    let exitCode: Int32
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

enum EngineError: LocalizedError {
    case bundledEngineMissing(String)
    case scriptMissing(String)
    case deploymentFailed(String)
    case themeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .bundledEngineMissing(let path):
            return "应用内缺少主题引擎：\(path)"
        case .scriptMissing(let path):
            return "主题脚本不存在：\(path)"
        case .deploymentFailed(let detail):
            return "主题引擎更新失败：\(detail)"
        case .themeUnavailable(let detail):
            return "无法读取当前主题：\(detail)"
        }
    }
}
