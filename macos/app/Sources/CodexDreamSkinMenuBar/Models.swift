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

struct ScriptResult {
    let exitCode: Int32
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

enum EngineError: LocalizedError {
    case bundledEngineMissing(String)
    case scriptMissing(String)
    case deploymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledEngineMissing(let path):
            return "应用内缺少主题引擎：\(path)"
        case .scriptMissing(let path):
            return "主题脚本不存在：\(path)"
        case .deploymentFailed(let detail):
            return "主题引擎更新失败：\(detail)"
        }
    }
}
