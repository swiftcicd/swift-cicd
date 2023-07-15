import Foundation

public protocol Tool: ContextAware {
    static var id: String { get }
    static var isInstalled: Bool { get async }
    static func install() async throws
    static func uninstall() async throws
}

public extension Tool {
    static var id: String { "\(Self.self)" }
}

public final class Tools: ContextAware {
    private var tools = [String: any Tool.Type]()

    public subscript<T: Tool>(tool: T.Type) -> T.Type {
        get async throws {
            if tools[tool.id] == nil {
                if await !tool.isInstalled {
                    context.logger.info("Installing \(tool.id)...")
                    try await tool.install()
                } else {
                    context.logger.info("Tool \(tool.id) is already installed")
                }
                tools[tool.id] = tool
            }

            return tool
        }
    }

    internal func uninstall() async {
        for tool in tools.values {
            do {
                if await tool.isInstalled {
                    context.logger.info("Uninstalling \(tool.id)...")
                    try await tool.uninstall()
                }
            } catch {
                context.logger.error("Failed to uninstall tool: \(tool.id)")
            }
        }
    }
}

extension ContextValues {
    enum ToolsKey: ContextKey {
        static let defaultValue = Tools()
    }

    public var tools: Tools {
        get { self[ToolsKey.self] }
        set { self[ToolsKey.self] = newValue }
    }
}
