import Foundation

public protocol Tool: ContextAware {
    static var name: String { get }
    static var isInstalled: Bool { get async }
    static func install() async throws
    static func uninstall() async throws
}

public extension Tool {
    static var name: String { "\(Self.self)" }

    static var isInstalled: Bool {
        get async {
            do {
                let output = try await context.shell("which \(name)", quiet: true)
                return !output.contains("not found")
            } catch {
                return false
            }
        }
    }

    /// Requires that the tool is installed. If the tool is not installed, an error is thrown.
    static func require() async throws {
        guard await isInstalled else {
            throw ActionError("\(name) is required but not installed.")
        }
    }
}

public final class Tools: ContextAware {
    private var tools = [String: any Tool.Type]()

    public subscript<T: Tool>(tool: T.Type) -> T.Type {
        get async throws {
            if tools[tool.name] == nil {
                if await !tool.isInstalled {
                    context.logger.info("Installing \(tool.name)...")
                    try await tool.install()
                } else {
                    context.logger.info("Tool \(tool.name) is already installed")
                }
                tools[tool.name] = tool
            }

            return tool
        }
    }

    internal func uninstall() async {
        guard !tools.isEmpty else {
            return
        }

        context.platform.startLogGroup(named: "Uninstalling tools...")

        for tool in tools.values {
            do {
                if await tool.isInstalled {
                    context.logger.info("Uninstalling \(tool.name)")
                    try await tool.uninstall()
                }
            } catch {
                context.logger.error("Failed to uninstall tool: \(tool.name)")
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
