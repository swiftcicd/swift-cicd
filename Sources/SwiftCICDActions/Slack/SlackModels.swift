public extension Slack {
    struct Message: Encodable {
        let attachments: [Attachments]

        public init(_ attachments: [Attachments]) {
            self.attachments = attachments
        }

        public init(color: String? = nil, blocks: [MessageBlock]) {
            self.init([Attachments(color: color, blocks: blocks)])
        }
    }

    struct Attachments: Encodable {
        let color: String?
        let blocks: [MessageBlock]

        public init(color: String? = nil, blocks: [MessageBlock]) {
            self.color = color
            self.blocks = blocks
        }
    }

    enum MessageBlock: Encodable {
        public static func text(_ text: String, emoji: Bool = true) -> MessageBlock {
            .section(SectionBlock(text: .text(text, emoji: emoji)))
        }

        public static func markdown(_ text: String) -> MessageBlock {
            .section(SectionBlock(text: .markdown(text)))
        }

        public static func context(elements: [TextBlock]) -> MessageBlock {
            .context(ContextBlock(elements: elements))
        }

        public static func actions(elements: [ButtonBlock]) -> MessageBlock {
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

    struct SectionBlock: Encodable {
        let type = "section"
        let text: TextBlock

        public init(text: TextBlock) {
            self.text = text
        }
    }

    struct ContextBlock: Encodable {
        let type = "context"
        let elements: [TextBlock]

        public init(elements: [TextBlock]) {
            self.elements = elements
        }
    }

    struct ActionsBlock: Encodable {
        let type = "actions"
        let elements: [ButtonBlock]

        public init(elements: [ButtonBlock]) {
            self.elements = elements
        }
    }

    enum TextBlock: Encodable {
        public static func text(_ text: String, emoji: Bool = true) -> TextBlock {
            .text(PlainTextBlock(text, emoji: emoji))
        }

        public static func markdown(_ text: String) -> TextBlock {
            .markdown(MarkdownTextBlock(text))
        }

        case text(PlainTextBlock)
        case markdown(MarkdownTextBlock)

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let plain): try container.encode(plain)
            case .markdown(let markdown): try container.encode(markdown)
            }
        }
    }

    struct PlainTextBlock: Encodable {
        let type = "plain_text"
        let text: String
        let emoji: Bool

        public init(_ text: String, emoji: Bool = true) {
            self.text = text
            self.emoji = emoji
        }
    }

    struct MarkdownTextBlock: Encodable {
        let type = "mrkdwn"
        let text: String

        public init(_ text: String) {
            self.text = text
        }
    }

    enum ButtonBlock: Encodable {
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

    struct LinkButton: Encodable {
        let type = "button"
        let text: TextBlock
        let url: String

        public init(text: TextBlock, url: String) {
            self.text = text
            self.url = url
        }
    }
}

extension Slack.TextBlock: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}
