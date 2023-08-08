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
        case attachments(SlackMessage.Attachments)
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

extension SlackMessage.Attachments: SlackBlockBuildable {
    public var block: SlackMessage._BuilderBlock { .attachments(self) }
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
public enum AttachmentsBuilder {
    public static func buildBlock(_ components: SlackBlockBuildable...) -> [SlackBlockBuildable] {
        components
    }

    public static func buildFinalResult(_ components: [SlackBlockBuildable]) -> [SlackMessage.Attachments] {
        var attachments = [SlackMessage.Attachments]()
        var attachment = SlackMessage.Attachments(blocks: [])

        for component in components {
            switch component.block {
            case .link(let linkButton):
                attachment.blocks.append(.actions(ActionsBlock(buttons: [.link(linkButton)])))
            case .button(let buttonBlock):
                attachment.blocks.append(.actions(ActionsBlock(buttons: [buttonBlock])))
            case .markdownText(let markdownTextBlock):
                attachment.blocks.append(.section(SectionBlock(text: .markdown(markdownTextBlock))))
            case .plainText(let plainTextBlock):
                attachment.blocks.append(.section(SectionBlock(text: .text(plainTextBlock))))
            case .text(let textBlock):
                attachment.blocks.append(.section(SectionBlock(text: textBlock)))
            case .actions(let actionsBlock):
                attachment.blocks.append(.actions(actionsBlock))
            case .context(let contextBlock):
                attachment.blocks.append(.context(contextBlock))
            case .section(let sectionBlock):
                attachment.blocks.append(.section(sectionBlock))
            case .message(let messageBlock):
                attachment.blocks.append(messageBlock)
            case .attachments(let _attachment):
                // If the current attachment has blocks
                if !attachment.blocks.isEmpty {
                    // Store the attachment and then reset it
                    attachments.append(attachment)
                    attachment = SlackMessage.Attachments(blocks: [])
                }
                // Add the attachment
                attachments.append(_attachment)
            }
        }

        // If the current attachment has blocks, add the attachment
        if !attachment.blocks.isEmpty {
            attachments.append(attachment)
        }

        return attachments
    }
}

//@resultBuilder
//public enum SlackMessageBuilder {
//    public static func buildBlock(_ components: SlackBlockBuildable...) -> [SlackBlockBuildable] {
//        components
//    }
//
//    public static func buildFinalResult(_ components: [SlackBlockBuildable]) -> SlackMessage {
//        var blocks = [GenericBlock]()
//        var attachments = [SlackMessage.Attachments]()
//
//        for component in components {
//            switch component.block {
//            case .link(let linkButton):
//                blocks.append(.actions(ActionsBlock(buttons: [.link(linkButton)])))
//            case .button(let buttonBlock):
//                blocks.append(.actions(ActionsBlock(buttons: [buttonBlock])))
//            case .markdownText(let markdownTextBlock):
//                blocks.append(.section(SectionBlock(text: .markdown(markdownTextBlock))))
//            case .plainText(let plainTextBlock):
//                blocks.append(.section(SectionBlock(text: .text(plainTextBlock))))
//            case .text(let textBlock):
//                blocks.append(.section(SectionBlock(text: textBlock)))
//            case .actions(let actionsBlock):
//                blocks.append(.actions(actionsBlock))
//            case .context(let contextBlock):
//                blocks.append(.context(contextBlock))
//            case .section(let sectionBlock):
//                blocks.append(.section(sectionBlock))
//            case .message(let messageBlock):
//                blocks.append(messageBlock)
//            case .attachments(let _attachments):
//                // If there is an attachment, and there are pending blocks
//                if !blocks.isEmpty {
//                    // Add the blocks to an attachment
//                    attachments.append(SlackMessage.Attachments(blocks: blocks))
//                    // Reset the blocks
//                    blocks = []
//                }
//                // Add the attachment
//                attachments.append(_attachments)
//            }
//        }
//
//        // If there are any blocks remaining, add them to an attachment.
//        if !blocks.isEmpty {
//            attachments.append(SlackMessage.Attachments(blocks: blocks))
//        }
//
//        return SlackMessage(attachments)
//    }
//}
