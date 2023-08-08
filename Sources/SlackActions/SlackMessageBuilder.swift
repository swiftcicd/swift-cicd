extension SlackMessage {
    public enum _BuilderBlock {
        case link(LinkButton)
        case button(GenericButtonBlock)
        case markdownText(MarkdownBlock)
        case plainText(TextBlock)
        case text(GenericTextBlock)
        case actions(ActionsBlock)
        case context(ContextBlock)
        case section(SectionBlock)
        case message(GenericBlock)
    }
}

public protocol TextBlockBuildable {
    var textBlock: GenericTextBlock { get }
}

extension MarkdownBlock: TextBlockBuildable {
    public var textBlock: GenericTextBlock { .markdown(self) }
}

extension TextBlock: TextBlockBuildable {
    public var textBlock: GenericTextBlock { .text(self) }
}

extension String: TextBlockBuildable {
    public var textBlock: GenericTextBlock { .text(self) }
}

public protocol ButtonBlockBuildable {
    var buttonBlock: GenericButtonBlock { get }
}

extension LinkButton: ButtonBlockBuildable {
    public var buttonBlock: GenericButtonBlock { .link(self) }
}

public protocol SlackBlockBuildable {
    var block: SlackMessage._BuilderBlock { get }
}

extension LinkButton: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .link(self) }
}

extension GenericButtonBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .button(self) }
}

extension MarkdownBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .markdownText(self) }
}

extension TextBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .plainText(self) }
}

extension GenericTextBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .text(self) }
}

extension ActionsBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .actions(self) }
}

extension ContextBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .context(self) }
}

extension SectionBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .section(self) }
}

extension GenericBlock: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .message(self) }
}

@resultBuilder
public enum StringBuilder {
    public static func buildArray(_ components: [String]) -> String {
        components.joined(separator: "\n")
    }

    public static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    public static func buildExpression(_ expression: String) -> String {
        expression
    }

    public static func buildLimitedAvailability(_ component: String) -> String {
        component
    }

    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }

    public static func buildPartialBlock(first: String) -> String {
        first
    }

    public static func buildPartialBlock(accumulated: String, next: String) -> String {
        accumulated + "\n" + next
    }
}

@resultBuilder
public enum TextBlocksBuilder {
    public static func buildArray(_ components: [[TextBlockBuildable]]) -> [TextBlockBuildable] {
        components.flatMap { $0 }
    }

    public static func buildBlock(_ blocks: TextBlockBuildable...) -> [TextBlockBuildable] {
        blocks
    }

    public static func buildBlock(_ blocks: [TextBlockBuildable]...) -> [TextBlockBuildable] {
        blocks.flatMap { $0 }
    }

    public static func buildExpression(_ expression: TextBlockBuildable) -> [TextBlockBuildable] {
        [expression]
    }

    public static func buildExpression(_ expression: [TextBlockBuildable]) -> [TextBlockBuildable] {
        expression
    }

    public static func buildOptional(_ component: [TextBlockBuildable]?) -> [TextBlockBuildable] {
        component ?? []
    }

    public static func buildFinalResult(_ blocks: [TextBlockBuildable]) -> [GenericTextBlock] {
        blocks.map(\.textBlock)
    }
}

@resultBuilder
public enum ButtonBlocksBuilder {
    public static func buildArray(_ components: [[ButtonBlockBuildable]]) -> [ButtonBlockBuildable] {
        components.flatMap { $0 }
    }

    public static func buildBlock(_ blocks: ButtonBlockBuildable...) -> [ButtonBlockBuildable] {
        blocks
    }

    public static func buildBlock(_ blocks: [ButtonBlockBuildable]...) -> [ButtonBlockBuildable] {
        blocks.flatMap { $0 }
    }

    public static func buildExpression(_ expression: ButtonBlockBuildable) -> [ButtonBlockBuildable] {
        [expression]
    }

    public static func buildExpression(_ expression: [ButtonBlockBuildable]) -> [ButtonBlockBuildable] {
        expression
    }

    public static func buildOptional(_ component: [ButtonBlockBuildable]?) -> [ButtonBlockBuildable] {
        component ?? []
    }

    public static func buildFinalResult(_ blocks: [ButtonBlockBuildable]) -> [GenericButtonBlock] {
        blocks.map(\.buttonBlock)
    }
}

@resultBuilder
public enum BlocksBuilder {
    public static func buildArray(_ components: [[SlackBlockBuildable]]) -> [SlackBlockBuildable] {
        components.flatMap { $0 }
    }

    public static func buildBlock(_ components: SlackBlockBuildable...) -> [SlackBlockBuildable] {
        components
    }

    public static func buildBlock(_ blocks: [SlackBlockBuildable]...) -> [SlackBlockBuildable] {
        blocks.flatMap { $0 }
    }

    public static func buildExpression(_ expression: SlackBlockBuildable) -> [SlackBlockBuildable] {
        [expression]
    }

    public static func buildExpression(_ expression: [SlackBlockBuildable]) -> [SlackBlockBuildable] {
        expression
    }


    public static func buildOptional(_ component: [SlackBlockBuildable]?) -> [SlackBlockBuildable] {
        component ?? []
    }

    public static func buildFinalResult(_ components: [SlackBlockBuildable]) -> [GenericBlock] {
        var blocks = [GenericBlock]()

        for component in components {
            switch component.block {
            case .link(let linkButton):
                blocks.append(.actions(ActionsBlock(buttons: [.link(linkButton)])))
            case .button(let buttonBlock):
                blocks.append(.actions(ActionsBlock(buttons: [buttonBlock])))
            case .markdownText(let markdownTextBlock):
                blocks.append(.section(SectionBlock(text: .markdown(markdownTextBlock))))
            case .plainText(let plainTextBlock):
                blocks.append(.section(SectionBlock(text: .text(plainTextBlock))))
            case .text(let textBlock):
                blocks.append(.section(SectionBlock(text: textBlock)))
            case .actions(let actionsBlock):
                blocks.append(.actions(actionsBlock))
            case .context(let contextBlock):
                blocks.append(.context(contextBlock))
            case .section(let sectionBlock):
                blocks.append(.section(sectionBlock))
            case .message(let messageBlock):
                blocks.append(messageBlock)
            }
        }

        return blocks
    }
}
