public struct SlackMessage: Encodable {
    let attachments: [Attachments]

    public init(_ attachments: [Attachments]) {
        self.attachments = attachments
    }

    public init(color: String? = nil, blocks: [SlackMessageBlock]) {
        self.init([Attachments(color: color, blocks: blocks)])
    }
}

public struct Attachments: Encodable {
    let color: String?
    let blocks: [SlackMessageBlock]

    public init(color: String? = nil, blocks: [SlackMessageBlock]) {
        self.color = color
        self.blocks = blocks
    }
}

public enum SlackMessageBlock: Encodable {
    public static func section(text: TextBlock) -> SlackMessageBlock {
        .section(SectionBlock(text: text))
    }

    public static func context(elements: [TextBlock]) -> SlackMessageBlock {
        .context(ContextBlock(elements: elements))
    }

    public static func actions(elements: [ButtonBlock]) -> SlackMessageBlock {
        .actions(ActionsBlock(elements: elements))
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
    let text: TextBlock

    public init(text: TextBlock) {
        self.text = text
    }
}

public struct ContextBlock: Encodable {
    let type = "context"
    let elements: [TextBlock]

    public init(elements: [TextBlock]) {
        self.elements = elements
    }
}

public struct ActionsBlock: Encodable {
    let type = "actions"
    let elements: [ButtonBlock]

    public init(elements: [ButtonBlock]) {
        self.elements = elements
    }
}

public enum TextBlock: Encodable {
    public static func plain(_ text: String, emoji: Bool = true) -> TextBlock {
        .plain(PlainTextBlock(text, emoji: emoji))
    }

    public static func markdown(_ text: String) -> TextBlock {
        .markdown(MarkdownTextBlock(text))
    }

    case plain(PlainTextBlock)
    case markdown(MarkdownTextBlock)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let plain): try container.encode(plain)
        case .markdown(let markdown): try container.encode(markdown)
        }
    }
}

extension TextBlock: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .plain(value)
    }
}

public struct PlainTextBlock: Encodable {
    let type = "plain_text"
    let text: String
    let emoji: Bool

    public init(_ text: String, emoji: Bool = true) {
        self.text = text
        self.emoji = emoji
    }
}

public struct MarkdownTextBlock: Encodable {
    let type = "mrkdwn"
    let text: String

    public init(_ text: String) {
        self.text = text
    }
}

public enum ButtonBlock: Encodable {
    public static func link(text: TextBlock, url: String) -> ButtonBlock {
        .link(LinkButton(text: text, url: url))
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
    let text: TextBlock
    let url: String

    public init(text: TextBlock, url: String) {
        self.text = text
        self.url = url
    }
}
