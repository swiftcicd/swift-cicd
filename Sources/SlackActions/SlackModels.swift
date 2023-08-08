// Message
//  - [Attachments]
//
// Attachments
//  - color
//  - [MessageBlock]
//
// MessageBlock
//  - SectionBlock
//      - TextBlock
//  - ContextBlock
//      - [TextBlock]
//  - ActionsBlock
//      - [ButtonBlock]
//
// TextBlock
//  - PlainText
//      - text
//      - isEmoji
//  - MarkdownText
//
// ButtonBlock
//  - LinkButton
//      - TextBlock
//      - url

public struct SlackMessage: Encodable {
    var attachments: [Attachments]

    public init(_ attachments: [Attachments]) {
        self.attachments = attachments
    }

    public init(color: String? = nil, blocks: [GenericBlock]) {
        self.init([Attachments(color: color, blocks: blocks)])
    }

    public init(color: String? = nil, @BlocksBuilder blocks: () -> [GenericBlock]) {
        self.init([Attachments(color: color, blocks: blocks())])
    }
}

extension SlackMessage {
    public struct Attachments: Encodable {
        let color: String?
        var blocks: [GenericBlock]

        public init(color: String? = nil, blocks: [GenericBlock]) {
            self.color = color
            self.blocks = blocks
        }
    }
}

public enum GenericBlock: Encodable {
    public static func text(emoji: Bool = true, _ text: String) -> GenericBlock {
        .section(SectionBlock(text: .text(emoji: emoji, text)))
    }

    public static func markdown(_ text: String) -> GenericBlock {
        .section(SectionBlock(text: .markdown(text)))
    }

    public static func context(elements: [GenericTextBlock]) -> GenericBlock {
        .context(ContextBlock(elements: elements))
    }

    public static func actions(buttons: [GenericButtonBlock]) -> GenericBlock {
        .actions(ActionsBlock(buttons: buttons))
    }

    case section(SectionBlock)
    case context(ContextBlock)
    case actions(ActionsBlock)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .section(let section): try container.encode(section)
        case .context(let context): try container.encode(context)
        case .actions(let actions): try container.encode(actions)
        }
    }
}

public struct SectionBlock: Encodable {
    let type = "section"
    let text: GenericTextBlock

    public init(text: GenericTextBlock) {
        self.text = text
    }

    public init(markdown: Bool = false, @StringBuilder text: () -> String) {
        if markdown {
            self.text = .markdown(text())
        } else {
            self.text = .text(text())
        }
    }
}

public struct ContextBlock: Encodable {
    var type = "context"
    let elements: [GenericTextBlock]

    public init(elements: [GenericTextBlock]) {
        self.elements = elements
    }

    public init(@TextBlocksBuilder elements: () -> [GenericTextBlock]) {
        self.elements = elements()
    }
}

public struct ActionsBlock: Encodable {
    let type = "actions"
    let elements: [GenericButtonBlock]

    public init(buttons: [GenericButtonBlock]) {
        self.elements = buttons
    }

    public init(@ButtonBlocksBuilder buttons: () -> [GenericButtonBlock]) {
        self.elements = buttons()
    }
}

public enum GenericButtonBlock: Encodable {
    public static func link(url: String, text: GenericTextBlock) -> GenericButtonBlock {
        .link(LinkButton(url: url, text: text))
    }

    case link(LinkButton)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .link(let link): try container.encode(link)
        }
    }
}

public struct LinkButton: Encodable {
    let type = "button"
    let url: String
    let text: GenericTextBlock

    public init(url: String, text: GenericTextBlock) {
        self.url = url
        self.text = text
    }

    public init(url: String, @StringBuilder text: () -> String) {
        self.url = url
        self.text = .text(text())
    }
}

public enum GenericTextBlock: Encodable {
    public static func text(emoji: Bool = true, _ text: String) -> GenericTextBlock {
        .text(TextBlock(emoji: emoji, text))
    }

    public static func markdown(_ text: String) -> GenericTextBlock {
        .markdown(MarkdownBlock(text))
    }

    case text(TextBlock)
    case markdown(MarkdownBlock)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let plain): try container.encode(plain)
        case .markdown(let markdown): try container.encode(markdown)
        }
    }
}

public struct TextBlock: Encodable {
    let type = "plain_text"
    public let text: String
    public let emoji: Bool

    public init(emoji: Bool = true, _ text: String) {
        self.emoji = emoji
        self.text = text
    }

    public init(emoji: Bool = true, @StringBuilder text: () -> String) {
        self.emoji = emoji
        self.text = text()
    }
}

public struct MarkdownBlock: Encodable {
    let type = "mrkdwn"
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public init(@StringBuilder text: () -> String) {
        self.text = text()
    }
}

extension GenericTextBlock: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}
